// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
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
import {RebalanceAction, TokenTransfer, ActionType, StrategyState} from "src/types/DataTypes.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, FeeManager, UUPSUpgradeable {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;

    // Base collateral ratio constant, 1e8 means that collateral / debt ratio is 1:1
    uint256 public constant BASE_RATIO = 1e8;
    uint256 public constant BASE_REWARD_PERCENTAGE = 1e5;
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

    /// @inheritdoc ILeverageManager
    function getIsLendingAdapterUsed(address lendingAdapter) public view returns (bool isUsed) {
        return Storage.layout().isLendingAdapterUsed[lendingAdapter];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCollateralAsset(IStrategy strategy) public view returns (IERC20 collateralAsset) {
        return getStrategyLendingAdapter(strategy).getCollateralAsset();
    }

    /// @inheritdoc ILeverageManager
    function getStrategyDebtAsset(IStrategy strategy) public view returns (IERC20 debtAsset) {
        return getStrategyLendingAdapter(strategy).getDebtAsset();
    }

    /// @inheritdoc ILeverageManager
    function getStrategyRebalanceReward(IStrategy strategy) public view returns (uint256 reward) {
        return Storage.layout().config[strategy].rebalanceRewardPercentage;
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
    function getStrategyCollateralRatios(IStrategy strategy) public view returns (CollateralRatios memory ratios) {
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
        setStrategyRebalanceReward(strategy, strategyConfig.rebalanceRewardPercentage);
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
    function setStrategyRebalanceReward(IStrategy strategy, uint256 reward) public onlyRole(MANAGER_ROLE) {
        if (reward > BASE_REWARD_PERCENTAGE) {
            revert InvalidRewardPercentage(reward);
        }

        Storage.layout().config[strategy].rebalanceRewardPercentage = reward;
        emit StrategyRebalanceRewardSet(strategy, reward);
    }

    /// @inheritdoc ILeverageManager
    function deposit(IStrategy strategy, uint256 collateralToAdd, uint256 debtToBorrow, uint256 minShares)
        external
        returns (uint256)
    {
        // Calculate equity
        uint256 equity =
            getStrategyLendingAdapter(strategy).convertCollateralToDebtAsset(collateralToAdd) - debtToBorrow;

        uint256 shares = _convertToShares(strategy, equity);
        uint256 sharesAfterFee = _computeFeeAdjustedShares(strategy, shares, IFeeManager.Action.Deposit);

        if (sharesAfterFee < minShares) {
            revert SlippageTooHigh(sharesAfterFee, minShares);
        }

        // Store strategy state before deposit
        StrategyState memory stateBefore = _getStrategyState(strategy);

        // Take asset from sender and supply it as collateral
        SafeERC20.safeTransferFrom(getStrategyCollateralAsset(strategy), msg.sender, address(this), collateralToAdd);
        _executeLendingAdapterAction(strategy, ActionType.AddCollateral, collateralToAdd);

        // Borrow and send debt assets to caller
        _executeLendingAdapterAction(strategy, ActionType.Borrow, debtToBorrow);
        SafeERC20.safeTransfer(getStrategyDebtAsset(strategy), msg.sender, debtToBorrow);

        // Get new strategy state
        StrategyState memory stateAfter = _getStrategyState(strategy);

        // Validate state after deposit
        _validateCollateralRatioAfterAction(strategy, stateBefore.collateralRatio, stateAfter.collateralRatio);

        // Mint shares to user
        strategy.mint(msg.sender, sharesAfterFee);

        // Emit event and explicit return statement
        emit Deposit(strategy, msg.sender, collateralToAdd, debtToBorrow, sharesAfterFee);
        return sharesAfterFee;
    }

    /// @inheritdoc ILeverageManager
    function redeem(IStrategy strategy, uint256 shares, uint256 minAssets) external returns (uint256 assets) {
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
        SafeERC20.safeTransferFrom(getStrategyDebtAsset(strategy), msg.sender, address(this), debt);
        _executeLendingAdapterAction(strategy, ActionType.Repay, debt);

        // Withdraw from lending pool and send assets to user
        _executeLendingAdapterAction(strategy, ActionType.RemoveCollateral, collateral);
        SafeERC20.safeTransfer(getStrategyCollateralAsset(strategy), msg.sender, collateral);

        // Emit event and explicit return statement
        emit Redeem(strategy, msg.sender, shares, collateral, debt);
        return collateral;
    }

    // @inheritdoc ILeverageManager
    function rebalance(
        RebalanceAction[] calldata actions,
        TokenTransfer[] calldata tokensIn,
        TokenTransfer[] calldata tokensOut
    ) external {
        _transferTokens(tokensIn, msg.sender, address(this));

        StrategyState[] memory strategiesStateBefore = new StrategyState[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            IStrategy strategy = actions[i].strategy;

            // Check if the strategy is eligible for rebalance if it has not been checked yet in a previous iteration of the loop
            if (!_isElementInSlice(actions, strategy, i)) {
                StrategyState memory state = _getStrategyState(strategy);
                strategiesStateBefore[i] = state;

                _validateRebalanceEligibility(strategy, state.collateralRatio);
            }

            _executeLendingAdapterAction(strategy, actions[i].actionType, actions[i].amount);
        }

        for (uint256 i = 0; i < actions.length; i++) {
            // Validate the strategy state after rebalancing if it has not been validated yet in a previous iteration of the loop
            if (!_isElementInSlice(actions, actions[i].strategy, i)) {
                _validateStrategyStateAfterRebalance(actions[i].strategy, strategiesStateBefore[i]);
            }
        }

        _transferTokens(tokensOut, address(this), msg.sender);
    }

    // Calculates how much debt should user repay to cover equity they want to redeem
    function _calculateCollateralAndDebtToCoverEquity(IStrategy strategy, uint256 equity, IFeeManager.Action action)
        internal
        view
        returns (uint256 collateral, uint256 debt)
    {
        // Get current collateral ratio and excess excess collateral in debt asset. Excess of collateral can be redeemed without repaying the debt
        (uint256 currCollateralRatio, int256 excessCollateral) = _getStrategyCollateralRatioAndExcess(strategy);

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
            equityToCover = equity;
            ratio = getStrategyTargetCollateralRatio(strategy);
        } else if (action == IFeeManager.Action.Redeem && !isOverCollateralized) {
            equityToCover = equity;
            ratio = currCollateralRatio;
        } else {
            equityToCover = equity > excessCollateralAbs ? equity - excessCollateralAbs : 0;
            ratio = getStrategyTargetCollateralRatio(strategy);
        }

        debt = Math.mulDiv(equityToCover, BASE_RATIO, ratio - BASE_RATIO);
        collateral = getStrategyLendingAdapter(strategy).convertDebtToCollateralAsset(debt + equity);

        return (collateral, debt);
    }

    /// @notice Calculates strategy collateral ratio and excess of collateral
    /// @param strategy Strategy to calculate this data for
    /// @return collateralRatio Collateral ratio calculated like: collateral value / debt value
    /// @return excessCollateral Excess of collateral calculated like: target collateral - debt
    /// @dev Excess of collateral can be negative. This would mean that strategy has less collateral than required
    function _getStrategyCollateralRatioAndExcess(IStrategy strategy)
        internal
        view
        returns (uint256 collateralRatio, int256 excessCollateral)
    {
        // Get collateral and debt of the strategy denominated in debt asset
        StrategyState memory state = _getStrategyState(strategy);

        // Calculate how much collateral should be in the strategy to match target ratio. Rounded up!
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
        uint256 targetCollateral = Math.mulDiv(state.debt, targetRatio, BASE_RATIO, Math.Rounding.Ceil);

        // Calculate excess of collateral. If collateral is higher than target excess will be positive, otherwise negative
        excessCollateral = state.collateral.toInt256() - targetCollateral.toInt256();

        return (state.collateralRatio, excessCollateral);
    }

    /// @notice Validates if strategy should be rebalanced
    /// @param strategy Strategy to validate
    /// @param currCollateralRatio Current collateral ratio of the strategy
    /// @dev Strategy should be rebalanced if it's collateral ratio is outside of the min/max range.
    ///      If strategy is not eligible for rebalance, function will revert
    function _validateRebalanceEligibility(IStrategy strategy, uint256 currCollateralRatio) internal view {
        CollateralRatios memory ratios = getStrategyCollateralRatios(strategy);

        if (currCollateralRatio >= ratios.minCollateralRatio && currCollateralRatio <= ratios.maxCollateralRatio) {
            revert StrategyNotEligibleForRebalance(strategy);
        }
    }

    /// @notice Validates if strategy is in better state after rebalance
    /// @param strategy Strategy to validate
    /// @param stateBefore State of the strategy before rebalance that includes collateral, debt, equity and collateral ratio
    /// @dev Function checks if collateral ratio is closer to target ratio than it was before rebalance. Function also checks
    ///      if equity is not too much lower. Rebalancer is allowed to take percentage of equity when rebalancing strategy.
    ///      This percentage is considered as reward for rebalancer.
    function _validateStrategyStateAfterRebalance(IStrategy strategy, StrategyState memory stateBefore) internal view {
        // Fetch state after rebalance
        StrategyState memory stateAfter = _getStrategyState(strategy);

        // Validate equity change
        _validateEquityChange(strategy, stateBefore, stateAfter);

        // Validate collateral ratio change
        _validateCollateralRatioAfterAction(strategy, stateBefore.collateralRatio, stateAfter.collateralRatio);
    }

    /// @notice Validates collateral ratio after action (Deposit, Withdraw, Rebalance)
    /// @param strategy Strategy to validate ratio for
    /// @param collateralRatioBefore Collateral ratio before action
    /// @param collateralRatioAfter Collateral ratio after action
    /// @dev Collateral ratio after action needs to be closer to target ratio than before action. Also both collateral ratios
    ///      need to be on the same side. This means if strategy was overexposed before action it can not be underexposed not and vice verse.
    function _validateCollateralRatioAfterAction(
        IStrategy strategy,
        uint256 collateralRatioBefore,
        uint256 collateralRatioAfter
    ) internal view {
        uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);

        int256 targetRatioDiffBefore = collateralRatioBefore.toInt256() - targetRatio.toInt256();
        int256 targetRatioDiffAfter = collateralRatioAfter.toInt256() - targetRatio.toInt256();

        if (targetRatioDiffBefore * targetRatioDiffAfter < 0) {
            revert ExposureDirectionChanged();
        }

        if (targetRatioDiffBefore.abs() < targetRatioDiffAfter.abs()) {
            revert CollateralRatioInvalid();
        }
    }

    /// @notice Validates that strategy has enough equity after rebalance action
    /// @param stateBefore State of the strategy before rebalance
    /// @param stateAfter State of the strategy after rebalance
    function _validateEquityChange(
        IStrategy strategy,
        StrategyState memory stateBefore,
        StrategyState memory stateAfter
    ) internal view {
        uint256 equityBefore = stateBefore.equity;
        uint256 equityAfter = stateAfter.equity;
        uint256 debtBefore = stateBefore.debt;
        uint256 debtAfter = stateAfter.debt;

        uint256 debtChange = (debtAfter.toInt256() - debtBefore.toInt256()).abs();
        uint256 reward = (debtChange * getStrategyRebalanceReward(strategy)) / BASE_REWARD_PERCENTAGE;

        if (equityAfter < equityBefore - reward) {
            revert EquityLossTooBig();
        }
    }

    /// @notice Returns all data required to describe current strategy state - collateral, debt, equity and collateral ratio
    /// @param strategy Strategy to query state for

    function _getStrategyState(IStrategy strategy) internal view returns (StrategyState memory) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        uint256 collateral = lendingAdapter.getCollateralInDebtAsset();
        uint256 debt = lendingAdapter.getDebt();
        uint256 equity = lendingAdapter.getEquityInDebtAsset();

        uint256 collateralRatio =
            debt > 0 ? Math.mulDiv(collateral, BASE_RATIO, debt, Math.Rounding.Floor) : type(uint256).max;

        return StrategyState({collateral: collateral, debt: debt, equity: equity, collateralRatio: collateralRatio});
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

    /// @notice Function that converts user's equity to shares, equity will be denominated in debt asset
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity for
    /// @param equity Equity to convert to shares, equity is denominated in debt asset
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(IStrategy strategy, uint256 equity) internal view returns (uint256 shares) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        return Math.mulDiv(
            equity,
            strategy.totalSupply() + 10 ** DECIMALS_OFFSET,
            lendingAdapter.getEquityInDebtAsset() + 1,
            Math.Rounding.Floor
        );
    }

    /// @notice Function that checks if specific element has already been processed in the slice up to the given index
    /// @param actions Entire array to go through
    /// @param strategy Element to search for
    /// @param untilIndex Search until this specific index
    /// @dev This function is used to check if we already stored the state of the strategy before rebalance.
    ///      This function is used to check if strategy state has been already validated after rebalance
    function _isElementInSlice(RebalanceAction[] calldata actions, IStrategy strategy, uint256 untilIndex)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < untilIndex; i++) {
            if (address(actions[i].strategy) == address(strategy)) {
                return true;
            }
        }

        return false;
    }

    /// @notice Executes action on lending adapter from specific strategy
    /// @param strategy Strategy to execute action on
    /// @param actionType Type of the action to execute
    /// @param amount Amount to execute action with
    function _executeLendingAdapterAction(IStrategy strategy, ActionType actionType, uint256 amount) internal {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        if (actionType == ActionType.AddCollateral) {
            IERC20 collateralAsset = lendingAdapter.getCollateralAsset();
            collateralAsset.approve(address(lendingAdapter), amount);
            lendingAdapter.addCollateral(amount);
        } else if (actionType == ActionType.RemoveCollateral) {
            lendingAdapter.removeCollateral(amount);
        } else if (actionType == ActionType.Borrow) {
            lendingAdapter.borrow(amount);
        } else if (actionType == ActionType.Repay) {
            IERC20 debtAsset = lendingAdapter.getDebtAsset();
            debtAsset.approve(address(lendingAdapter), amount);
            lendingAdapter.repay(amount);
        }
    }

    /// @notice Batched token transfer
    /// @param transfers Array of transfer data. Transfer data consist of token to transfer and amount
    /// @param from Address to transfer tokens from
    /// @param to Address to transfer tokens to
    /// @dev If from address is this smart contract it will use regular transfer function otherwise it will use transferFrom
    function _transferTokens(TokenTransfer[] calldata transfers, address from, address to) internal {
        for (uint256 i = 0; i < transfers.length; i++) {
            TokenTransfer calldata transfer = transfers[i];

            if (from == address(this)) {
                SafeERC20.safeTransfer(IERC20(transfer.token), to, transfer.amount);
            } else {
                SafeERC20.safeTransferFrom(IERC20(transfer.token), from, to, transfer.amount);
            }
        }
    }
}
