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
    function getStrategyEquityInDebtAsset(address strategy) public view returns (uint256 equity) {
        return getLendingContract().getStrategyEquityInDebtAsset(strategy);
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
        bool isValid = ratios.minForRebalance <= ratios.target && ratios.target <= ratios.maxForRebalance;
        if (!isValid) {
            revert InvalidCollateralRatios();
        }

        Storage.layout().config[strategy].collateralRatios = ratios;
        emit StrategyCollateralRatiosSet(strategy, ratios);
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

        // Calculate how much to borrow and how much shares to mint for user. It must be done before supplying and borrowing
        (uint256 debtToBorrow, uint256 sharesToMint) = _calculateDebtAndShares(strategy, lendingContract, assets);

        // Charge strategy fee and mint shares for user. Revert if user does not receive enough shares
        _chargeStrategyFeeAndMintShares(strategy, recipient, sharesToMint, minShares);

        // Take collateral tokens from caller and supply them as collateral on lending pool
        SafeERC20.safeTransferFrom(IERC20(getStrategyCollateralAsset(strategy)), msg.sender, address(this), assets);
        lendingContract.supply(strategy, assets);

        // Borrow and send debt assets to user
        lendingContract.borrow(strategy, debtToBorrow);
        SafeERC20.safeTransfer(IERC20(getStrategyDebtAsset(strategy)), recipient, debtToBorrow);

        // Emit event and explicit return statement
        emit Deposit(strategy, msg.sender, recipient, assets, sharesToMint);
        return sharesToMint;
    }

    // Calculate how much of a debt asset to borrow and how much shares should be minted for user for given collateral
    function _calculateDebtAndShares(address strategy, ILendingContract lendingContract, uint256 collateral)
        internal
        view
        returns (uint256 debt, uint256 shares)
    {
        // Calculate how much of a debt corresponds to collateral. Debt is rounded down, debt = collateral / target ratio
        uint256 collateralInDebtAsset = lendingContract.convertCollateralToDebtAsset(strategy, collateral);
        uint256 debtToBorrow = Math.mulDiv(
            collateralInDebtAsset, BASE_RATIO, getStrategyTargetCollateralRatio(strategy), Math.Rounding.Floor
        );

        // Calculate how much shares user should receive for their equity
        uint256 equityInDebtAsset = collateralInDebtAsset - debtToBorrow;
        uint256 sharesToMint = _convertToShares(strategy, equityInDebtAsset);

        return (debtToBorrow, sharesToMint);
    }

    function _chargeStrategyFeeAndMintShares(address strategy, address recipient, uint256 shares, uint256 minShares)
        internal
    {
        // Calculate fee amount and deduct it from user's shares. Share fees are burned which increases overall share value
        uint256 sharesToMint = _chargeStrategyFee(strategy, shares, IFeeManager.Action.Deposit);

        // Revert if user does not receive enough shares
        if (sharesToMint < minShares) {
            revert InsufficientShares();
        }

        _mintShares(strategy, recipient, shares);
    }

    function _mintShares(address strategy, address recipient, uint256 shares) internal {
        Storage.Layout storage $ = Storage.layout();
        $.userStrategyShares[strategy][recipient] += shares;
        $.totalShares[strategy] += shares;
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

        // Burn shares from the user and decrease total shares in circulation. Burn them before sending tokens to user
        $.userStrategyShares[strategy][msg.sender] -= shares;
        $.totalShares[strategy] -= shares;

        // Charge strategy fee. Fee is not sent to treasury but burned which increases overall share value
        shares = _chargeStrategyFee(strategy, shares, IFeeManager.Action.Withdraw);

        uint256 equity = _convertToEquity(strategy, shares);
        uint256 debtToRepay = _calculateDebtToCoverEquity(strategy, lendingContract, equity);

        // Take assets from user and repay the debt
        SafeERC20.safeTransferFrom(IERC20(getStrategyDebtAsset(strategy)), msg.sender, address(this), debtToRepay);
        lendingContract.repay(strategy, debtToRepay);

        // Calculate how much collateral assets user will receive for their equity and debt repaid
        uint256 userCollateralAssets = lendingContract.convertBaseToCollateralAsset(strategy, equity + debtToRepay);

        // Revert if user does not receive enough assets
        if (userCollateralAssets < minAssets) {
            revert InsufficientAssets();
        }

        // Withdraw from lending pool and send assets to user
        lendingContract.withdraw(strategy, userCollateralAssets);
        SafeERC20.safeTransfer(IERC20(getStrategyCollateralAsset(strategy)), recipient, userCollateralAssets);

        // Emit event and explicit return statement
        emit Redeem(strategy, msg.sender, recipient, shares, userCollateralAssets);
        return userCollateralAssets;
    }

    // Calculates how much debt should user repay to cover equity they want to redeem
    function _calculateDebtToCoverEquity(address strategy, ILendingContract lendingContract, uint256 equity)
        internal
        view
        returns (uint256 requiredDebt)
    {
        // Get excess excess collateral in debt asset. Excess of collateral can be redeemed without repaying the debt
        uint256 excessCollateral = _calculateExcessOfCollateral(strategy, lendingContract);

        // If strategy has enough excess of collateral, user can redeem their equity without repaying any debt
        if (excessCollateral >= equity) {
            return 0;
        }

        // Equity that user needs to repay debt for
        uint256 equityToCover = equity - excessCollateral;

        // TODO: This is second read of the same variable from storage in this function. Optimize this
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);

        // Debt to repay = equity / (target ratio - 1). Rounded up.
        requiredDebt = Math.mulDiv(equityToCover, BASE_RATIO, targetRatio - BASE_RATIO, Math.Rounding.Ceil);

        return requiredDebt;
    }

    // This function calculates how much excess of collateral strategy has denominated in debt asset
    function _calculateExcessOfCollateral(address strategy, ILendingContract lendingContract)
        internal
        view
        returns (uint256 excessCollateral)
    {
        // Get collateral and debt of the strategy denominated in debt asset
        uint256 collateral = lendingContract.getStrategyCollateralInDebtAsset(strategy);
        uint256 debt = lendingContract.getStrategyDebt(strategy);

        // Calculate how much collateral should be in the strategy to match target ratio
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
        uint256 targetCollateral = Math.mulDiv(debt, targetRatio, BASE_RATIO, Math.Rounding.Ceil);

        // Calculate excess of collateral. If collateral is higher than target, return the difference, otherwise return 0
        return collateral > targetCollateral ? collateral - targetCollateral : 0;
    }

    /// @notice Function that converts user's equity denominated in debt asset to strategy shares, base asset can be USD or any other asset
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity to shares for
    /// @param equity Equity to convert to shares
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(address strategy, uint256 equity) internal view returns (uint256 shares) {
        return Math.mulDiv(
            equity,
            getTotalStrategyShares(strategy) + 10 ** _decimalsOffset(),
            getStrategyEquityInDebtAsset(strategy) + 1,
            Math.Rounding.Floor
        );
    }

    function _convertToEquity(address strategy, uint256 shares) internal view returns (uint256 equityInDebtAsset) {
        return Math.mulDiv(
            shares,
            getStrategyEquityInDebtAsset(strategy) + 1,
            getTotalStrategyShares(strategy) + 10 ** _decimalsOffset(),
            Math.Rounding.Ceil
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
