// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {FeeManager} from "src/FeeManager.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";
import {Strategy} from "src/Strategy.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, FeeManager, UUPSUpgradeable {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;

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
    function getStrategyTokenFactory() public view returns (IBeaconProxyFactory factory) {
        return Storage.layout().strategyTokenFactory;
    }

    function getIsLendingAdapterUsed(address lendingAdapter) public view returns (bool isUsed) {
        return Storage.layout().isLendingAdapterUsed[lendingAdapter];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyConfig(IStrategy strategy) external view returns (Storage.StrategyConfig memory config) {
        return Storage.layout().config[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyLendingAdapter(IStrategy strategy) public view returns (ILendingAdapter adapter) {
        return Storage.layout().config[strategy].lendingAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralAsset(IStrategy strategy) external view returns (IERC20 collateralAsset) {
        return getStrategyLendingAdapter(strategy).getCollateralAsset();
    }

    /// @inheritdoc ILeverageManager
    function getStrategyDebtAsset(IStrategy strategy) external view returns (IERC20 debtAsset) {
        return getStrategyLendingAdapter(strategy).getDebtAsset();
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralRatios(IStrategy strategy) external view returns (CollateralRatios memory ratios) {
        Storage.StrategyConfig storage config = Storage.layout().config[strategy];

        return CollateralRatios({
            minCollateralRatio: config.minCollateralRatio,
            maxCollateralRatio: config.maxCollateralRatio,
            targetCollateralRatio: config.targetCollateralRatio
        });
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralCap(IStrategy strategy) public view returns (uint256 collateralCap) {
        return Storage.layout().config[strategy].collateralCap;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyTargetCollateralRatio(IStrategy strategy) public view returns (uint256 targetCollateralRatio) {
        return Storage.layout().config[strategy].targetCollateralRatio;
    }

    /// @inheritdoc ILeverageManager
    function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        public
        view
        returns (uint256, uint256, uint256)
    {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);
        uint256 equityInDebtAsset = lendingAdapter.convertCollateralToDebtAsset(equityInCollateralAsset);
        (uint256 collateral, uint256 debt) =
            _calculateCollateralAndDebtToCoverEquity(strategy, equityInDebtAsset, IFeeManager.Action.Deposit);

        uint256 feeAdjustedShares = _convertToShares(strategy, equityInDebtAsset);
        uint256 shares = _computeSharesBeforeFeeAdjustment(strategy, feeAdjustedShares, IFeeManager.Action.Deposit);

        return (shares, collateral, debt);
    }

    /// @inheritdoc ILeverageManager
    function previewMint(IStrategy strategy, uint256 shares) public view returns (uint256, uint256, uint256) {
        uint256 feeAdjustedShares = _computeFeeAdjustedShares(strategy, shares, IFeeManager.Action.Deposit);
        uint256 equityInDebtAsset = _convertToEquity(strategy, feeAdjustedShares);

        (uint256 collateral, uint256 debt) =
            _calculateCollateralAndDebtToCoverEquity(strategy, equityInDebtAsset, IFeeManager.Action.Deposit);

        return (equityInDebtAsset, collateral, debt);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyTokenFactory(address factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Storage.layout().strategyTokenFactory = IBeaconProxyFactory(factory);
        emit StrategyTokenFactorySet(factory);
    }

    /// @inheritdoc ILeverageManager
    function createNewStrategy(Storage.StrategyConfig calldata strategyConfig, string memory name, string memory symbol)
        external
        onlyRole(MANAGER_ROLE)
        returns (IStrategy strategy)
    {
        IBeaconProxyFactory strategyTokenFactory = getStrategyTokenFactory();

        strategy = IStrategy(
            strategyTokenFactory.createProxy(
                abi.encodeWithSelector(Strategy.initialize.selector, address(this), name, symbol),
                bytes32(strategyTokenFactory.getProxies().length)
            )
        );

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

        emit StrategyCreated(
            strategy,
            strategyConfig.lendingAdapter.getCollateralAsset(),
            strategyConfig.lendingAdapter.getDebtAsset(),
            strategyConfig
        );
        return strategy;
    }

    /// @inheritdoc ILeverageManager
    function setStrategyLendingAdapter(IStrategy strategy, address adapter) public onlyRole(MANAGER_ROLE) {
        if (getIsLendingAdapterUsed(adapter)) {
            revert LendingAdapterAlreadyInUse(adapter);
        }

        Storage.Layout storage $ = Storage.layout();
        $.isLendingAdapterUsed[address(getStrategyLendingAdapter(strategy))] = false;

        $.config[strategy].lendingAdapter = ILendingAdapter(adapter);
        $.isLendingAdapterUsed[adapter] = true;

        emit StrategyLendingAdapterSet(strategy, adapter);
    }

    /// @inheritdoc ILeverageManager
    function setStrategyCollateralRatios(IStrategy strategy, CollateralRatios memory ratios)
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
    function setStrategyCollateralCap(IStrategy strategy, uint256 collateralCap) public onlyRole(MANAGER_ROLE) {
        Storage.layout().config[strategy].collateralCap = collateralCap;
        emit StrategyCollateralCapSet(strategy, collateralCap);
    }

    /// @inheritdoc ILeverageManager
    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (uint256)
    {
        uint256 equityInDebtAsset =
            getStrategyLendingAdapter(strategy).convertCollateralToDebtAsset(equityInCollateralAsset);
        uint256 feeAdjustedShares = _convertToShares(strategy, equityInDebtAsset);
        uint256 shares = _computeSharesBeforeFeeAdjustment(strategy, feeAdjustedShares, IFeeManager.Action.Deposit);

        // The shares before the fee adjustment is what is minted to the user. The fee adjusted shares is used to calculate the required collateral and debt
        if (shares < minShares) {
            revert SlippageTooHigh(shares, minShares);
        }

        mint(strategy, shares, equityInDebtAsset);

        return shares;
    }

    /// @inheritdoc ILeverageManager
    function mint(IStrategy strategy, uint256 shares, uint256 maxEquityInDebtAsset) public returns (uint256) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        // Charge strategy fee. Fee is not sent to treasury but burned which increases overall share value
        (uint256 equityInDebtAsset, uint256 collateral, uint256 debt) = previewMint(strategy, shares);

        if (equityInDebtAsset > maxEquityInDebtAsset) {
            revert SlippageTooHigh(equityInDebtAsset, maxEquityInDebtAsset);
        }

        // Take asset from sender and supply it as collateral
        IERC20 collateralAsset = lendingAdapter.getCollateralAsset();
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), collateral);

        collateralAsset.approve(address(lendingAdapter), collateral);
        lendingAdapter.addCollateral(collateral);

        // Borrow and send debt assets to caller
        lendingAdapter.borrow(debt);
        SafeERC20.safeTransfer(lendingAdapter.getDebtAsset(), msg.sender, debt);

        // Mint shares to user
        strategy.mint(msg.sender, shares);

        emit Deposit(strategy, msg.sender, msg.sender, equityInDebtAsset, shares);
        return equityInDebtAsset;
    }

    /// @inheritdoc ILeverageManager
    function redeem(IStrategy strategy, uint256 shares, uint256 minAssets) external returns (uint256 assets) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        // Charge strategy fee. Fee is not sent to treasury but burned which increases overall share value
        uint256 sharesAfterFee = _computeFeeAdjustedShares(strategy, shares, IFeeManager.Action.Redeem);
        uint256 equity = _convertToEquity(strategy, sharesAfterFee);

        // Revert if user does not receive enough assets
        if (equity < minAssets) {
            revert SlippageTooHigh(equity, minAssets);
        }

        (uint256 collateral, uint256 debt) =
            _calculateCollateralAndDebtToCoverEquity(strategy, equity, IFeeManager.Action.Redeem);

        // Burn shares from user and total supply
        strategy.burn(msg.sender, shares);

        // Take assets from sender and repay the debt
        IERC20 debtAsset = lendingAdapter.getDebtAsset();
        SafeERC20.safeTransferFrom(debtAsset, msg.sender, address(this), debt);

        debtAsset.approve(address(lendingAdapter), debt);
        lendingAdapter.repay(debt);

        // Withdraw from lending pool and send assets to user
        lendingAdapter.removeCollateral(collateral);
        SafeERC20.safeTransfer(lendingAdapter.getCollateralAsset(), msg.sender, collateral);

        // Emit event and explicit return statement
        emit Redeem(strategy, msg.sender, shares, collateral, debt);
        return collateral;
    }

    // Calculates how much debt should user repay to cover equity (denominated in debt asset) they want to redeem
    function _calculateCollateralAndDebtToCoverEquity(
        IStrategy strategy,
        uint256 equityInDebtAsset,
        IFeeManager.Action action
    ) public view returns (uint256 collateral, uint256 debt) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        // Get current collateral ratio and excess excess collateral in debt asset. Excess of collateral can be redeemed without repaying the debt
        (uint256 currCollateralRatio, int256 excessCollateral) =
            _getStrategyCollateralRatioAndExcess(strategy, lendingAdapter);

        // Determine if the strategy is over-collateralized
        bool isOverCollateralized = excessCollateral >= 0;
        uint256 excessCollateralAbs = excessCollateral.abs();

        uint256 ratio;
        uint256 equityToCover;

        // If strategy has enough collateral, optimization is not possible on the deposit action and we need to cover all equity by following the target ratio
        // If the strategy has less collateral than needed, the optimization is as follows:
        //     1. Deposit collateral assets to cover the collateral deficit, without borrowing additional debt assets
        //     2. For the remaining equity (equal to `equity - collateral from 1.`), borrow debt assets and take collateral asset from the user based on the target ratio
        // As a result, the strategy will be at healthier state - either at the target ratio (if depositing equity > collateral deficit) or closer to the target ratio.
        // Note: The same optimization can be done in reverse for withdraw actions.
        if (action == IFeeManager.Action.Deposit && isOverCollateralized) {
            equityToCover = equityInDebtAsset;
            ratio = getStrategyTargetCollateralRatio(strategy);
        } else if (action == IFeeManager.Action.Redeem && !isOverCollateralized) {
            equityToCover = equityInDebtAsset;
            ratio = currCollateralRatio;
        } else {
            equityToCover = equityInDebtAsset > excessCollateralAbs ? equityInDebtAsset - excessCollateralAbs : 0;
            ratio = getStrategyTargetCollateralRatio(strategy);
        }

        debt = Math.mulDiv(equityToCover, BASE_RATIO, ratio - BASE_RATIO);
        collateral = lendingAdapter.convertDebtToCollateralAsset(debt + equityInDebtAsset);

        return (collateral, debt);
    }

    // This function calculates how much excess of collateral strategy has denominated in debt asset and current collateral ratio
    function _getStrategyCollateralRatioAndExcess(IStrategy strategy, ILendingAdapter lendingAdapter)
        internal
        view
        returns (uint256 currCollateralRatio, int256 excessCollateral)
    {
        // Get collateral and debt of the strategy denominated in debt asset
        uint256 collateral = lendingAdapter.getCollateralInDebtAsset();
        uint256 debt = lendingAdapter.getDebt();

        if (debt == 0) {
            return (type(uint256).max, collateral.toInt256());
        }

        // Calculate how much collateral should be in the strategy to match target ratio. Rounded up!
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
        uint256 targetCollateral = Math.mulDiv(debt, targetRatio, BASE_RATIO, Math.Rounding.Ceil);

        // Calculate excess of collateral. If collateral is higher than target excess will be positive, otherwise negative
        excessCollateral = collateral.toInt256() - targetCollateral.toInt256();
        currCollateralRatio = Math.mulDiv(collateral, BASE_RATIO, debt, Math.Rounding.Floor);

        return (currCollateralRatio, excessCollateral);
    }

    /// @notice Converts equity denominated in debt asset to shares
    /// @param strategy Strategy to convert equity to shares for
    /// @param equityInDebtAsset Equity denominated in debt asset to convert to shares
    /// @return shares Equity in shares
    function _convertToShares(IStrategy strategy, uint256 equityInDebtAsset) internal view returns (uint256) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        return Math.mulDiv(
            equityInDebtAsset,
            strategy.totalSupply() + 10 ** DECIMALS_OFFSET,
            lendingAdapter.getEquityInDebtAsset() + 1,
            Math.Rounding.Floor
        );
    }

    /// @notice Function that converts user's shares to strategy equity, equity will be denominated in debt asset
    /// @notice Function uses OZ formula for calculating assets
    /// @param strategy Strategy to convert shares for
    /// @param shares Shares to convert to equity
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their shares
    function _convertToEquity(IStrategy strategy, uint256 shares) internal view returns (uint256 equityInDebtAsset) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        return Math.mulDiv(
            shares,
            lendingAdapter.getEquityInDebtAsset() + 1,
            strategy.totalSupply() + 10 ** DECIMALS_OFFSET,
            Math.Rounding.Floor
        );
    }
}
