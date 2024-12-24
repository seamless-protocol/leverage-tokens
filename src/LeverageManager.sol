// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {FeeManager} from "src/FeeManager.sol";
import {ERC6909} from "./ERC6909.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, ERC6909, FeeManager, UUPSUpgradeable {
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
    function getStrategyConfig(uint256 strategyId) external view returns (Storage.StrategyConfig memory config) {
        return Storage.layout().config[strategyId];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCore(uint256 strategyId) external view returns (Storage.StrategyCore memory core) {
        return Storage.layout().config[strategyId].core;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralRatios(uint256 strategyId)
        external
        view
        returns (Storage.CollateralRatios memory ratios)
    {
        return Storage.layout().config[strategyId].collateralRatios;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCap(uint256 strategyId) external view returns (uint256 cap) {
        return Storage.layout().config[strategyId].cap;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyEquityInDebtAsset(uint256 strategyId) public view returns (uint256 equity) {
        return getLendingContract().getStrategyEquityInDebtAsset(strategyId);
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralAsset(uint256 strategyId) public view returns (address collateral) {
        return Storage.layout().config[strategyId].core.collateral;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyDebtAsset(uint256 strategyId) public view returns (address debt) {
        return Storage.layout().config[strategyId].core.debt;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyTargetCollateralRatio(uint256 strategyId) public view returns (uint256 targetRatio) {
        return Storage.layout().config[strategyId].collateralRatios.target;
    }

    function setLendingContract(address lendingContract) external onlyRole(MANAGER_ROLE) {
        Storage.layout().lendingContract = lendingContract;
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCore(uint256 strategyId, Storage.StrategyCore memory core) external onlyRole(MANAGER_ROLE) {
        // Check does strategy already have core settings configured
        if (getStrategyCollateralAsset(strategyId) != address(0)) {
            revert CoreAlreadySet();
        }

        // Check does provided core has zero addresses for collateral and debt
        if (core.collateral == address(0) || core.debt == address(0)) {
            revert InvalidStrategyCore();
        }

        Storage.layout().config[strategyId].core = core;
        emit StrategyCoreSet(strategyId, core);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCollateralRatios(uint256 strategyId, Storage.CollateralRatios calldata ratios)
        external
        onlyRole(MANAGER_ROLE)
    {
        // Validate that target ratio is in between min and max rebalance ratios before setting
        bool isValid = ratios.minForRebalance <= ratios.target && ratios.target <= ratios.maxForRebalance;
        if (!isValid) {
            revert InvalidCollateralRatios();
        }

        Storage.layout().config[strategyId].collateralRatios = ratios;
        emit StrategyCollateralRatiosSet(strategyId, ratios);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCap(uint256 strategyId, uint256 cap) external onlyRole(MANAGER_ROLE) {
        Storage.layout().config[strategyId].cap = cap;
        emit StrategyCapSet(strategyId, cap);
    }

    /// @inheritdoc ILeverageManager
    function deposit(uint256 strategyId, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares)
    {
        // Cache
        ILendingContract lendingContract = getLendingContract();

        // Calculate how much to borrow and how much shares to mint for user. It must be done before supplying and borrowing
        (uint256 debtToBorrow, uint256 sharesToMint) = _calculateDebtAndShares(strategyId, lendingContract, assets);

        // Charge strategy fee and mint shares for user. Revert if user does not receive enough shares
        uint256 mintedShares = _chargeStrategyFeeAndMintShares(strategyId, recipient, sharesToMint, minShares);

        // Take collateral tokens from caller and supply them as collateral on lending pool
        SafeERC20.safeTransferFrom(IERC20(getStrategyCollateralAsset(strategyId)), msg.sender, address(this), assets);
        lendingContract.supply(strategyId, assets);

        // Borrow and send debt assets to user
        lendingContract.borrow(strategyId, debtToBorrow);
        SafeERC20.safeTransfer(IERC20(getStrategyDebtAsset(strategyId)), msg.sender, debtToBorrow);

        // Emit event and explicit return statement
        emit Deposit(strategyId, msg.sender, recipient, assets, mintedShares);
        return mintedShares;
    }

    // Calculate how much of a debt asset to borrow and how much shares should be minted for user for given collateral
    function _calculateDebtAndShares(uint256 strategyId, ILendingContract lendingContract, uint256 collateral)
        internal
        view
        returns (uint256 debt, uint256 shares)
    {
        // Calculate how much of a debt corresponds to collateral. Debt is rounded down, debt = collateral / target ratio
        uint256 collateralInDebtAsset = lendingContract.convertCollateralToDebtAsset(strategyId, collateral);

        uint256 debtToBorrow = Math.mulDiv(
            collateralInDebtAsset, BASE_RATIO, getStrategyTargetCollateralRatio(strategyId), Math.Rounding.Ceil
        );

        // Calculate how much shares user should receive for their equity
        uint256 equityInDebtAsset = collateralInDebtAsset - debtToBorrow;
        uint256 sharesToMint = _convertToShares(strategyId, equityInDebtAsset);

        return (debtToBorrow, sharesToMint);
    }

    function _chargeStrategyFeeAndMintShares(uint256 strategyId, address recipient, uint256 shares, uint256 minShares)
        internal
        returns (uint256 sharesMinted)
    {
        // Calculate fee amount and deduct it from user's shares. Share fees are burned which increases overall share value
        uint256 sharesToMint = _chargeStrategyFee(strategyId, shares, IFeeManager.Action.Deposit);

        // Revert if user does not receive enough shares
        if (sharesToMint < minShares) {
            revert InsufficientShares();
        }

        _mint(recipient, strategyId, sharesToMint);
        return sharesToMint;
    }

    /// @inheritdoc ILeverageManager
    function redeem(uint256 strategyId, uint256 shares, address recipient, uint256 minAssets)
        external
        returns (uint256 assets)
    {
        ILendingContract lendingContract = getLendingContract();

        // Charge strategy fee. Fee is not sent to treasury but burned which increases overall share value
        uint256 sharesAfterFee = _chargeStrategyFee(strategyId, shares, IFeeManager.Action.Withdraw);

        uint256 equity = _convertToEquity(strategyId, sharesAfterFee);
        uint256 debtToRepay = _calculateDebtToCoverEquity(strategyId, lendingContract, equity);

        // Calculate how much collateral we need to give to user for their debt repaid. Important to calculate before repaying the debt
        uint256 userCollateralAssets = lendingContract.convertBaseToCollateralAsset(strategyId, equity + debtToRepay);

        // Revert if user does not receive enough assets
        if (userCollateralAssets < minAssets) {
            revert InsufficientAssets();
        }

        // Burn shares from user and total supply
        _burn(msg.sender, strategyId, shares);

        // Take assets from user and repay the debt
        SafeERC20.safeTransferFrom(IERC20(getStrategyDebtAsset(strategyId)), msg.sender, address(this), debtToRepay);
        lendingContract.repay(strategyId, debtToRepay);

        // Withdraw from lending pool and send assets to user
        lendingContract.withdraw(strategyId, userCollateralAssets);
        SafeERC20.safeTransfer(IERC20(getStrategyCollateralAsset(strategyId)), recipient, userCollateralAssets);

        // Emit event and explicit return statement
        emit Redeem(strategyId, msg.sender, recipient, shares, userCollateralAssets);
        return userCollateralAssets;
    }

    // Calculates how much debt should user repay to cover equity they want to redeem
    function _calculateDebtToCoverEquity(uint256 strategyId, ILendingContract lendingContract, uint256 equity)
        internal
        view
        returns (uint256 requiredDebt)
    {
        // Get excess excess collateral in debt asset. Excess of collateral can be redeemed without repaying the debt
        uint256 excessCollateral = _calculateExcessOfCollateral(strategyId, lendingContract);

        // If strategy has enough excess of collateral, user can redeem their equity without repaying any debt
        if (excessCollateral >= equity) {
            return 0;
        }

        // Equity that user needs to repay debt for
        uint256 equityToCover = equity - excessCollateral;

        // TODO: This is second read of the same variable from storage in this function. Optimize this
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategyId);

        // Debt to repay = equity / (target ratio - 1). Rounded up.
        requiredDebt = Math.mulDiv(equityToCover, BASE_RATIO, targetRatio - BASE_RATIO, Math.Rounding.Ceil);

        return requiredDebt;
    }

    // This function calculates how much excess of collateral strategy has denominated in debt asset
    function _calculateExcessOfCollateral(uint256 strategyId, ILendingContract lendingContract)
        internal
        view
        returns (uint256 excessCollateral)
    {
        // Get collateral and debt of the strategy denominated in debt asset
        uint256 collateral = lendingContract.getStrategyCollateralInDebtAsset(strategyId);
        uint256 debt = lendingContract.getStrategyDebt(strategyId);

        // Calculate how much collateral should be in the strategy to match target ratio
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategyId);
        uint256 targetCollateral = Math.mulDiv(debt, targetRatio, BASE_RATIO, Math.Rounding.Ceil);

        // Calculate excess of collateral. If collateral is higher than target, return the difference, otherwise return 0
        return collateral > targetCollateral ? collateral - targetCollateral : 0;
    }

    /// @notice Function that converts user's equity denominated in debt asset to strategy shares, base asset can be USD or any other asset
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategyId Strategy to convert equity to shares for
    /// @param equity Equity to convert to shares
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(uint256 strategyId, uint256 equity) internal view returns (uint256 shares) {
        return Math.mulDiv(
            equity,
            totalSupply(strategyId) + 10 ** _decimalsOffset(),
            getStrategyEquityInDebtAsset(strategyId) + 1,
            Math.Rounding.Floor
        );
    }

    function _convertToEquity(uint256 strategyId, uint256 shares) internal view returns (uint256 equityInDebtAsset) {
        return Math.mulDiv(
            shares,
            getStrategyEquityInDebtAsset(strategyId) + 1,
            totalSupply(strategyId) + 10 ** _decimalsOffset(),
            Math.Rounding.Floor
        );
    }

    function _decimalsOffset() private pure returns (uint256 shares) {
        return 0;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC6909)
        returns (bool)
    {
        return AccessControlUpgradeable.supportsInterface(interfaceId) || ERC6909.supportsInterface(interfaceId);
    }

    /// @inheritdoc ILeverageManager
    function pause() external {}

    /// @inheritdoc ILeverageManager
    function unpause() external {}

    /// @inheritdoc ILeverageManager
    function pauseStrategy(uint256 strategyId) external {}

    /// @inheritdoc ILeverageManager
    function unpauseStrategy(uint256 strategyId) external {}

    function getStrategyCollateral(uint256 strategyId) external view returns (uint256 collateral) {}

    function getStrategyDebt(uint256 strategyId) external view returns (uint256 debt) {}

    function getStrategyEquity(uint256 strategyId) external view returns (uint256 equity) {}

    function getStrategyEquityUSD(uint256 strategyId) external view returns (uint256 equityUSD) {}

    function getUserStrategyAssets(uint256 strategyId, address user) external view returns (uint256 assets) {}
}
