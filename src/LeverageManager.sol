// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {FeeManager} from "src/FeeManager.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, FeeManager, UUPSUpgradeable {
    // Base collateral ratio constant, 1e8 means that collateral / debt ratio is 1:1
    uint256 public constant BASE_RATIO = 1e8;
    uint256 public constant DECIMALS_OFFSET = 0;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    function initialize(address initialAdmin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ILeverageManager
    function getStrategyConfig(address strategy) external view returns (Storage.StrategyConfig memory config) {
        return Storage.layout().config[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyLendingAdapter(address strategy) public view returns (ILendingAdapter adapter) {
        return Storage.layout().config[strategy].lendingAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralRatios(address strategy) external view returns (CollateralRatios memory ratios) {
        Storage.StrategyConfig storage config = Storage.layout().config[strategy];

        return CollateralRatios({
            minCollateralRatio: config.minCollateralRatio,
            maxCollateralRatio: config.maxCollateralRatio,
            targetCollateralRatio: config.targetCollateralRatio
        });
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralCap(address strategy) public view returns (uint256 collateralCap) {
        return Storage.layout().config[strategy].collateralCap;
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
    function getStrategyCollateralAsset(address strategy) public view returns (address collateral) {
        return Storage.layout().config[strategy].collateralAsset;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyDebtAsset(address strategy) public view returns (address debt) {
        return Storage.layout().config[strategy].debtAsset;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyTargetCollateralRatio(address strategy) public view returns (uint256 targetCollateralRatio) {
        return Storage.layout().config[strategy].targetCollateralRatio;
    }

    /// @inheritdoc ILeverageManager
    function createNewStrategy(address strategy, Storage.StrategyConfig calldata strategyConfig)
        external
        onlyRole(MANAGER_ROLE)
    {
        // Check does strategy already have core settings configured
        if (getStrategyCollateralAsset(strategy) != address(0)) {
            revert StrategyAlreadyExists(strategy);
        }

        setStrategyLendingAdapter(strategy, address(strategyConfig.lendingAdapter));
        setStrategyCollateralCap(strategy, strategyConfig.collateralCap);
        setStrategyCollateralRatios(
            strategy,
            CollateralRatios({
                minCollateralRatio: strategyConfig.minCollateralRatio,
                targetCollateralRatio: strategyConfig.targetCollateralRatio,
                maxCollateralRatio: strategyConfig.maxCollateralRatio
            })
        );

        // Check does provided core has zero addresses for collateral and debt
        if (strategyConfig.collateralAsset == address(0) || strategyConfig.debtAsset == address(0)) {
            revert InvalidStrategyAssets();
        }

        Storage.Layout storage $ = Storage.layout();
        $.config[strategy].collateralAsset = strategyConfig.collateralAsset;
        $.config[strategy].debtAsset = strategyConfig.debtAsset;
        emit StrategyCreated(strategy, strategyConfig.collateralAsset, strategyConfig.debtAsset);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyLendingAdapter(address strategy, address adapter) public onlyRole(MANAGER_ROLE) {
        Storage.layout().config[strategy].lendingAdapter = ILendingAdapter(adapter);
        emit StrategyLendingAdapterSet(strategy, adapter);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCollateralRatios(address strategy, CollateralRatios memory ratios)
        public
        onlyRole(MANAGER_ROLE)
    {
        // Validate that target ratio is in between min and max rebalance ratios before setting
        bool isValid = ratios.targetCollateralRatio > BASE_RATIO
            && ratios.minCollateralRatio <= ratios.targetCollateralRatio
            && ratios.targetCollateralRatio <= ratios.maxCollateralRatio;

        if (!isValid) {
            revert InvalidCollateralRatios();
        }

        Storage.StrategyConfig storage config = Storage.layout().config[strategy];
        config.minCollateralRatio = ratios.minCollateralRatio;
        config.maxCollateralRatio = ratios.maxCollateralRatio;
        config.targetCollateralRatio = ratios.targetCollateralRatio;

        emit StrategyCollateralRatiosSet(strategy, ratios);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCollateralCap(address strategy, uint256 collateralCap) public onlyRole(MANAGER_ROLE) {
        Storage.layout().config[strategy].collateralCap = collateralCap;
        emit StrategyCollateralCapSet(strategy, collateralCap);
    }

    /// @inheritdoc ILeverageManager
    function deposit(address strategy, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares)
    {
        // Cache
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        // Calculate how much to borrow and how much shares to mint for user. It must be done before supplying and borrowing
        (uint256 collateral, uint256 debtToBorrow, uint256 sharesToMint) =
            _calculateCollateralDebtAndShares(strategy, lendingAdapter, assets);

        // Revert if there is not enough space in the strategy
        uint256 currCollateral = lendingAdapter.getStrategyCollateral(strategy);
        uint256 collateralCap = getStrategyCollateralCap(strategy);

        if (currCollateral + collateral > collateralCap) {
            revert CollateralExceedsCap(currCollateral + collateral, collateralCap);
        }

        // Charge strategy fee and mint shares for user. Revert if user does not receive enough shares
        uint256 mintedShares = _chargeStrategyFeeAndMintShares(strategy, recipient, sharesToMint, minShares);

        // Take collateral tokens from caller and supply them as collateral on lending pool
        IERC20 collateralAsset = IERC20(getStrategyCollateralAsset(strategy));
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), collateral);

        collateralAsset.approve(address(lendingAdapter), collateral);
        lendingAdapter.addCollateral(strategy, collateral);

        // Borrow and send debt assets to caller
        lendingAdapter.borrow(strategy, debtToBorrow);
        SafeERC20.safeTransfer(IERC20(getStrategyDebtAsset(strategy)), msg.sender, debtToBorrow);

        // Emit event and explicit return statement
        emit Deposit(strategy, msg.sender, recipient, assets, mintedShares);
        return mintedShares;
    }

    // Calculate how much of a debt asset to borrow and how much shares should be minted for user for given equity assets
    function _calculateCollateralDebtAndShares(address strategy, ILendingAdapter lendingAdapter, uint256 assets)
        internal
        view
        returns (uint256 collateral, uint256 debt, uint256 shares)
    {
        // Convert user's equity to debt asset and calculate how much to borrow
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
        uint256 equityInDebtAsset = lendingAdapter.convertCollateralToDebtAsset(strategy, assets);

        // debt = equity / (1 - targetRatio), collateral = equity * targetRatio / (targetRatio - 1)
        debt = Math.mulDiv(equityInDebtAsset, BASE_RATIO, targetRatio - BASE_RATIO, Math.Rounding.Floor);
        collateral = Math.mulDiv(assets, targetRatio, targetRatio - BASE_RATIO, Math.Rounding.Ceil);

        uint256 sharesToMint = _convertToShares(strategy, equityInDebtAsset);

        return (collateral, debt, sharesToMint);
    }

    function _chargeStrategyFeeAndMintShares(address strategy, address recipient, uint256 shares, uint256 minShares)
        internal
        returns (uint256 sharesMinted)
    {
        // Calculate fee amount and deduct it from user's shares. Share fees are burned which increases overall share value
        uint256 sharesToMint = _chargeStrategyFee(strategy, shares, IFeeManager.Action.Deposit);

        // Revert if user does not receive enough shares
        if (sharesToMint < minShares) {
            revert InsufficientShares(sharesToMint, minShares);
        }

        _mintShares(strategy, recipient, sharesToMint);
        return sharesToMint;
    }

    function _mintShares(address strategy, address recipient, uint256 shares) internal {
        Storage.Layout storage $ = Storage.layout();
        $.userStrategyShares[strategy][recipient] += shares;
        $.totalShares[strategy] += shares;

        emit Mint(strategy, recipient, shares);
    }

    /// @inheritdoc ILeverageManager
    function redeem(address strategy, uint256 shares, uint256 minAssets) external returns (uint256 assets) {
        uint256 userSharesBalance = getUserStrategyShares(strategy, msg.sender);
        if (userSharesBalance < shares) {
            revert InsufficientBalance(shares, userSharesBalance);
        }

        Storage.Layout storage $ = Storage.layout();
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        // Charge strategy fee. Fee is not sent to treasury but burned which increases overall share value
        uint256 sharesAfterFee = _chargeStrategyFee(strategy, shares, IFeeManager.Action.Redeem);
        uint256 equity = _convertToEquity(strategy, sharesAfterFee);

        // Revert if user does not receive enough assets
        if (equity < minAssets) {
            revert InsufficientAssets(equity, minAssets);
        }

        (uint256 collateral, uint256 debt) = _calculateCollateralAndDebtToCoverEquity(strategy, lendingAdapter, equity);

        // Burn shares from user and total supply
        $.userStrategyShares[strategy][msg.sender] -= shares;
        $.totalShares[strategy] -= shares;

        // Take assets from sender and repay the debt
        IERC20 debtAsset = IERC20(getStrategyDebtAsset(strategy));
        SafeERC20.safeTransferFrom(debtAsset, msg.sender, address(this), debt);

        debtAsset.approve(address(lendingAdapter), debt);
        lendingAdapter.repay(strategy, debt);

        // Withdraw from lending pool and send assets to user
        lendingAdapter.removeCollateral(strategy, collateral);
        SafeERC20.safeTransfer(IERC20(getStrategyCollateralAsset(strategy)), msg.sender, collateral);

        // Emit event and explicit return statement
        emit Redeem(strategy, msg.sender, shares, collateral, debt);
        return collateral;
    }

    // Calculates how much debt should user repay to cover equity they want to redeem
    function _calculateCollateralAndDebtToCoverEquity(address strategy, ILendingAdapter lendingAdapter, uint256 equity)
        internal
        view
        returns (uint256 collateral, uint256 debt)
    {
        // Get current collateral ratio and excess excess collateral in debt asset. Excess of collateral can be redeemed without repaying the debt
        (uint256 currCollateralRatio, uint256 excessCollateral) =
            _getStrategyCollateralRatioAndExcess(strategy, lendingAdapter);

        // If strategy has enough excess there is no debt to cover just withdraw collateral otherwise debt needs to be calculated
        if (excessCollateral < equity) {
            // Equity that user needs to repay debt for
            uint256 equityToCover = equity - excessCollateral;

            // After withdrawing any excess collateral, the strategy will be at target ratio.
            // Thus, the amount of debt to be repaid to withdraw the remaining equity can be calculated using the target ratio.
            // If there is no excess collateral, the amount of debt to be repaid needs to use the current collateral ratio.
            uint256 ratio = excessCollateral > 0 ? getStrategyTargetCollateralRatio(strategy) : currCollateralRatio;

            // Debt to repay = equity / (ratio - 1)
            debt = Math.mulDiv(equityToCover, BASE_RATIO, ratio - BASE_RATIO);
        }

        collateral = lendingAdapter.convertDebtToCollateralAsset(strategy, debt + equity);
        return (collateral, debt);
    }

    // This function calculates how much excess of collateral strategy has denominated in debt asset
    function _getStrategyCollateralRatioAndExcess(address strategy, ILendingAdapter lendingAdapter)
        internal
        view
        returns (uint256 currCollateralRatio, uint256 excessCollateral)
    {
        // Get collateral and debt of the strategy denominated in debt asset
        uint256 collateral = lendingAdapter.getStrategyCollateralInDebtAsset(strategy);
        uint256 debt = lendingAdapter.getStrategyDebt(strategy);

        // Calculate how much collateral should be in the strategy to match target ratio. Rounded up!
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
        uint256 targetCollateral = Math.mulDiv(debt, targetRatio, BASE_RATIO, Math.Rounding.Ceil);

        // Calculate excess of collateral. If collateral is higher than target, return the difference, otherwise return 0
        excessCollateral = collateral > targetCollateral ? collateral - targetCollateral : 0;
        currCollateralRatio = Math.mulDiv(collateral, BASE_RATIO, debt, Math.Rounding.Floor);

        return (currCollateralRatio, excessCollateral);
    }

    /// @notice Function that converts user's equity denominated in debt asset to strategy shares, base asset can be USD or any other asset
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity to shares for
    /// @param equity Equity to convert to shares
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(address strategy, uint256 equity) internal view returns (uint256 shares) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        return Math.mulDiv(
            equity,
            getTotalStrategyShares(strategy) + 10 ** DECIMALS_OFFSET,
            lendingAdapter.getStrategyEquityInDebtAsset(strategy) + 1,
            Math.Rounding.Floor
        );
    }

    /// @notice Function that converts user's shares to strategy equity, equity will be denominated in debt asset
    /// @notice Function uses OZ formula for calculating assets
    /// @param strategy Strategy to convert shares for
    /// @param shares Shares to convert to equity
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their shares
    function _convertToEquity(address strategy, uint256 shares) internal view returns (uint256 equityInDebtAsset) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        return Math.mulDiv(
            shares,
            lendingAdapter.getStrategyEquityInDebtAsset(strategy) + 1,
            getTotalStrategyShares(strategy) + 10 ** DECIMALS_OFFSET,
            Math.Rounding.Floor
        );
    }
}
