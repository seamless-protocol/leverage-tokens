// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {FeeManager} from "src/FeeManager.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ILendingContract} from "src/interfaces/ILendingContract.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, FeeManager, UUPSUpgradeable {
    // Base collateral ratio constant, 1e8 = 1x
    uint256 public constant BASE_RATIO = 1e8;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    function initialize(address initialAdmin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function getLendingContract() public view returns (ILendingContract lendingContract) {
        return ILendingContract(Storage.layout().lendingContract);
    }

    /// @inheritdoc ILeverageManager
    function getStrategyConfig(address strategy) external view returns (Storage.StrategyConfig memory config) {
        return Storage.layout().config[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCore(address strategy) external view returns (Storage.StrategyCore memory core) {
        return Storage.layout().config[strategy].core;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralRatios(address strategy)
        external
        view
        returns (Storage.CollateralRatios memory ratios)
    {
        return Storage.layout().config[strategy].collateralRatios;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCap(address strategy) external view returns (uint256 cap) {
        return Storage.layout().config[strategy].cap;
    }

    /// @inheritdoc ILeverageManager
    function getTotalStrategyShares(address strategy) public view returns (uint256 shares) {
        return Storage.layout().totalShares[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getUserStrategyShares(address strategy, address user) public view returns (uint256 shares) {
        return Storage.layout().userStrategyShares[strategy][user];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyEquityInBaseAsset(address strategy) public view returns (uint256 equity) {
        return getLendingContract().getStrategyEquityInBaseAsset(strategy);
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralAsset(address strategy) public view returns (address collateral) {
        return Storage.layout().config[strategy].core.collateral;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyDebtAsset(address strategy) public view returns (address debt) {
        return Storage.layout().config[strategy].core.debt;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyTargetCollateralRatio(address strategy) public view returns (uint256 targetRatio) {
        return Storage.layout().config[strategy].collateralRatios.target;
    }

    function setLendingContract(address lendingContract) external onlyRole(MANAGER_ROLE) {
        Storage.layout().lendingContract = lendingContract;
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCore(address strategy, Storage.StrategyCore memory core) external onlyRole(MANAGER_ROLE) {
        // Check does strategy already have core settings configured
        if (getStrategyCollateralAsset(strategy) != address(0)) {
            revert CoreAlreadySet();
        }

        // Check does provided core has zero addresses for collateral and debt
        if (core.collateral == address(0) || core.debt == address(0)) {
            revert InvalidStrategyCore();
        }

        Storage.layout().config[strategy].core = core;
        emit StrategyCoreSet(strategy, core);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCollateralRatios(address strategy, Storage.CollateralRatios calldata ratios)
        external
        onlyRole(MANAGER_ROLE)
    {
        // Validate that target ratio is in between min and max rebalance ratios before setting
        _validateCollateralRatios(ratios);

        Storage.layout().config[strategy].collateralRatios = ratios;
        emit StrategyCollateralRatiosSet(strategy, ratios);
    }

    // Validates that target ratio is in between min and max for rebalance ratios
    function _validateCollateralRatios(Storage.CollateralRatios calldata ratios) private pure {
        bool isValid = ratios.minForRebalance <= ratios.target && ratios.target <= ratios.maxForRebalance;
        if (!isValid) {
            revert InvalidCollateralRatios();
        }
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCap(address strategy, uint256 cap) external onlyRole(MANAGER_ROLE) {
        Storage.layout().config[strategy].cap = cap;
        emit StrategyCapSet(strategy, cap);
    }

    /// @inheritdoc ILeverageManager
    function deposit(address strategy, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares)
    {
        // Cache
        ILendingContract lendingContract = getLendingContract();

        // Calculate how much to borrow and how much shares to mint for user
        (uint256 debtToBorrow, uint256 sharesToMint) = _calculateDebtAndShares(strategy, lendingContract, assets);

        // Calculate fee amount and deduct it from user's shares
        // Fee shares are not sent to the treasury they are not minted which means they are burned
        // This is done to prevent gaming. Share burning will increase overall share value of all users
        sharesToMint = _chargeStrategyFee(strategy, sharesToMint, IFeeManager.Action.Deposit);

        // Revert if user does not receive enough shares
        if (sharesToMint < minShares) {
            revert InsufficientShares();
        }

        // Take collateral tokens from caller and supply them as collateral on lending pool
        SafeERC20.safeTransferFrom(IERC20(getStrategyCollateralAsset(strategy)), msg.sender, address(this), assets);
        lendingContract.supply(strategy, assets);

        // Borrow and send debt assets to user
        lendingContract.borrow(strategy, debtToBorrow);
        SafeERC20.safeTransfer(IERC20(getStrategyDebtAsset(strategy)), recipient, debtToBorrow);

        // Give shares to the user and increase total shares in circulation
        _mintStrategyShares(strategy, recipient, sharesToMint);

        // Emit event and explicit return statement
        emit Deposit(strategy, msg.sender, recipient, assets, sharesToMint);
        return sharesToMint;
    }

    // Calculate how much of a debt asset to borrow and how much shares should be minted for user for given collateral
    function _calculateDebtAndShares(address strategy, ILendingContract lendingContract, uint256 collateral)
        private
        view
        returns (uint256 debt, uint256 shares)
    {
        // Calculate how much of a debt corresponds to deposited collateral asset based on target ratio
        // It is important to round down debt, debt = collateral / target ratio
        uint256 debtInCollateralAsset =
            Math.mulDiv(collateral, BASE_RATIO, getStrategyTargetCollateralRatio(strategy), Math.Rounding.Floor);
        uint256 debtToBorrow = lendingContract.convertCollateralToDebtAsset(strategy, debtInCollateralAsset);

        // Calculate how much shares user should receive for their equity
        // It is important to calculate shares prior to supplying and borrowing
        uint256 equityInBaseAsset =
            lendingContract.convertCollateralToBaseAsset(strategy, collateral - debtInCollateralAsset);
        uint256 sharesToMint = _convertToShares(strategy, equityInBaseAsset);

        return (debtToBorrow, sharesToMint);
    }

    // This function mints shares for user and increases total shares in circulation
    function _mintStrategyShares(address strategy, address recipient, uint256 shares) private {
        Storage.Layout storage $ = Storage.layout();

        $.userStrategyShares[strategy][recipient] += shares;
        $.totalShares[strategy] += shares;

        // TODO: Should we emit event here?
    }

    /// @inheritdoc ILeverageManager
    function redeem(address strategy, uint256 shares, address recipient, uint256 minAssets)
        external
        returns (uint256 assets)
    {
        if (getUserStrategyShares(strategy, msg.sender) < shares) {
            revert InsufficientBalance();
        }

        Storage.Layout storage $ = Storage.layout();
        ILendingContract lendingContract = getLendingContract();

        shares -= _chargeStrategyFee(strategy, shares, IFeeManager.Action.Withdraw);

        // Cache
        uint256 strategyCollateralBase = lendingContract.getStrategyCollateralInBaseAsset(strategy);
        uint256 strategyDebtBase = lendingContract.getStrategyDebtInBaseAsset(strategy);
        uint256 totalStrategyShares = getTotalStrategyShares(strategy);

        uint256 userCollateralBase =
            Math.mulDiv(strategyCollateralBase, shares, totalStrategyShares, Math.Rounding.Floor);

        // Get excess excess collateral in USD
        // Excess of collateral can be redeemed without repaying the debt because strategy is leveraged up
        uint256 excessCollateralBase = _calculateExcessOfCollateralUSD(
            strategyCollateralBase, strategyDebtBase, getStrategyTargetCollateralRatio(strategy)
        );

        // If strategy does not have enough excess of collateral, user should repay some debt
        if (excessCollateralBase < userCollateralBase) {
            // Calculated how much debt in base asset should be repaid by user
            // Calculation is done by calculating entire debt that user should repay for this collateral
            // and then discounting it by the debt that covers excess of collateral
            uint256 debtDiscountBase =
                Math.mulDiv(excessCollateralBase, strategyDebtBase, strategyCollateralBase, Math.Rounding.Floor);

            // Entire user's portion of debt without discount, round up
            uint256 userEntireDebtBase = Math.mulDiv(strategyDebtBase, shares, totalStrategyShares, Math.Rounding.Ceil);

            // Calculate how much debt assets user should give for debt repay, debt is rounded up because discount is rounded down
            uint256 userDebtAssets =
                lendingContract.convertBaseToDebtAsset(strategy, userEntireDebtBase - debtDiscountBase); // This assets should be rounded up in LendingLib

            // Takes assets from caller and repays the debt
            SafeERC20.safeTransferFrom(
                IERC20(getStrategyDebtAsset(strategy)), msg.sender, address(this), userDebtAssets
            );
            lendingContract.repay(strategy, userDebtAssets);
        }

        // Burn shares from the user and decrease total shares in circulation. Burn them before sending tokens to user
        $.userStrategyShares[strategy][msg.sender] -= shares;
        $.totalShares[strategy] -= shares;

        // Withdraw collateral from lending pool, charge withdraw fees on collateral tokens and send assets to recipient
        uint256 userCollateralAssets = lendingContract.convertBaseToCollateralAsset(strategy, userCollateralBase);
        lendingContract.withdraw(strategy, userCollateralAssets);

        // Revert if user does not receive enough assets
        if (userCollateralAssets < minAssets) {
            revert InsufficientAssets();
        }

        SafeERC20.safeTransfer(IERC20(getStrategyCollateralAsset(strategy)), recipient, userCollateralAssets);

        // Emit event and explicit return statement
        emit Redeem(strategy, msg.sender, recipient, shares, userCollateralAssets);
        return userCollateralAssets;
    }

    // This function calculates how much excess of collateral strategy has denominated in base asset
    function _calculateExcessOfCollateralUSD(uint256 collateralBase, uint256 debtBase, uint256 targetRatio)
        private
        pure
        returns (uint256 excessCollateralBase)
    {
        // Calculate how much collateral should be in the strategy for current debt so strategy is perfectly balanced, rounded up
        uint256 targetCollateralBase = Math.mulDiv(debtBase, targetRatio, BASE_RATIO, Math.Rounding.Ceil);
        return collateralBase > targetCollateralBase ? collateralBase - targetCollateralBase : 0;
    }

    /// @notice Function that converts user's equity denominated in base asset to strategy shares, base asset can be USD or any other asset
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity to shares for
    /// @param equity Equity to convert to shares
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(address strategy, uint256 equity) private view returns (uint256 shares) {
        return Math.mulDiv(
            equity,
            getTotalStrategyShares(strategy) + 10 ** _decimalsOffset(),
            getStrategyEquityInBaseAsset(strategy) + 1,
            Math.Rounding.Floor
        );
    }

    function _decimalsOffset() private pure returns (uint256 shares) {
        return 0;
    }

    /// @inheritdoc ILeverageManager
    function pause() external {}

    /// @inheritdoc ILeverageManager
    function unpause() external {}

    /// @inheritdoc ILeverageManager
    function pauseStrategy(address strategy) external {}

    /// @inheritdoc ILeverageManager
    function unpauseStrategy(address strategy) external {}

    function getStrategyCollateral(address strategy) external view returns (uint256 collateral) {}

    function getStrategyDebt(address strategy) external view returns (uint256 debt) {}

    function getStrategyEquity(address strategy) external view returns (uint256 equity) {}

    function getStrategyEquityUSD(address strategy) external view returns (uint256 equityUSD) {}

    function getUserStrategyAssets(address strategy, address user) external view returns (uint256 assets) {}
}
