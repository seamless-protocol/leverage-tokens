// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

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
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {FeeManager} from "src/FeeManager.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {Strategy} from "src/Strategy.sol";
import {ActionData, ActionType, ExternalAction, RebalanceAction, TokenTransfer} from "src/types/DataTypes.sol";
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, FeeManager, UUPSUpgradeable {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;

    // Base collateral ratio constant, 1e8 means that collateral / debt ratio is 1:1
    uint256 public constant BASE_RATIO = 1e8;
    uint256 public constant DECIMALS_OFFSET = 0;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct LeverageManagerStorage {
        /// @dev Factory for deploying new strategy tokens when creating new strategies
        IBeaconProxyFactory strategyTokenFactory;
        /// @dev Strategy address => Config for strategy
        mapping(IStrategy strategy => ILeverageManager.StrategyConfig) config;
        /// @dev Lending adapter address => Is lending adapter registered. Two strategies can't have same lending adapter
        mapping(address lendingAdapter => bool) isLendingAdapterUsed;
    }

    function _getLeverageManagerStorage() internal pure returns (LeverageManagerStorage storage $) {
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600
        }
    }

    function initialize(address initialAdmin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ILeverageManager
    function getStrategyTokenFactory() public view returns (IBeaconProxyFactory factory) {
        return _getLeverageManagerStorage().strategyTokenFactory;
    }

    /// @inheritdoc ILeverageManager
    function getIsLendingAdapterUsed(address lendingAdapter) public view returns (bool isUsed) {
        return _getLeverageManagerStorage().isLendingAdapterUsed[lendingAdapter];
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
    function getStrategyRebalanceModule(IStrategy strategy) public view returns (IRebalanceModule adapter) {
        return _getLeverageManagerStorage().config[strategy].rebalanceAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyConfig(IStrategy strategy) external view returns (StrategyConfig memory config) {
        return _getLeverageManagerStorage().config[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyLendingAdapter(IStrategy strategy) public view returns (ILendingAdapter adapter) {
        return _getLeverageManagerStorage().config[strategy].lendingAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyTargetCollateralRatio(IStrategy strategy) public view returns (uint256 targetCollateralRatio) {
        return _getLeverageManagerStorage().config[strategy].targetCollateralRatio;
    }

    /// @inheritdoc ILeverageManager
    function getStrategyState(IStrategy strategy) public view returns (StrategyState memory state) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        uint256 collateral = lendingAdapter.getCollateralInDebtAsset();
        uint256 debt = lendingAdapter.getDebt();
        uint256 equity = lendingAdapter.getEquityInDebtAsset();

        uint256 collateralRatio =
            debt > 0 ? Math.mulDiv(collateral, BASE_RATIO, debt, Math.Rounding.Floor) : type(uint256).max;

        return StrategyState({
            collateralInDebtAsset: collateral,
            debt: debt,
            equity: equity,
            collateralRatio: collateralRatio
        });
    }

    /// @inheritdoc ILeverageManager
    function setStrategyTokenFactory(address factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getLeverageManagerStorage().strategyTokenFactory = IBeaconProxyFactory(factory);
        emit StrategyTokenFactorySet(factory);
    }

    /// @inheritdoc ILeverageManager
    function createNewStrategy(StrategyConfig calldata strategyConfig, string memory name, string memory symbol)
        external
        returns (IStrategy strategy)
    {
        IBeaconProxyFactory strategyTokenFactory = getStrategyTokenFactory();

        strategy = IStrategy(
            strategyTokenFactory.createProxy(
                abi.encodeWithSelector(Strategy.initialize.selector, address(this), name, symbol),
                bytes32(strategyTokenFactory.getProxies().length)
            )
        );

        if (getIsLendingAdapterUsed(address(strategyConfig.lendingAdapter))) {
            revert LendingAdapterAlreadyInUse(address(strategyConfig.lendingAdapter));
        }

        _getLeverageManagerStorage().config[strategy] = strategyConfig;
        _getLeverageManagerStorage().isLendingAdapterUsed[address(strategyConfig.lendingAdapter)] = true;

        emit StrategyCreated(
            strategy,
            strategyConfig.lendingAdapter.getCollateralAsset(),
            strategyConfig.lendingAdapter.getDebtAsset(),
            strategyConfig
        );
        return strategy;
    }

    /// @inheritdoc ILeverageManager
    function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        public
        view
        returns (ActionData memory)
    {
        ActionData memory data = _previewAction(strategy, equityInCollateralAsset, ExternalAction.Deposit);

        // For deposits, the collateral amount returned by the preview is the total collateral required to execute the
        // deposit, so we add the treasury fee to it, since the collateral computed above is wrt the equity amount with
        // the treasury fee subtracted.
        data.collateral += data.treasuryFee;

        return data;
    }

    /// @inheritdoc ILeverageManager
    function previewWithdraw(IStrategy strategy, uint256 equityInCollateralAsset)
        public
        view
        returns (ActionData memory)
    {
        ActionData memory data = _previewAction(strategy, equityInCollateralAsset, ExternalAction.Withdraw);

        // For withdrawals, the collateral amount returned is the collateral transferred to the sender, so we subtract the
        // treasury fee, since the collateral computed by `previewAction` is wrt the equity amount without the treasury fee
        // subtracted.
        // Note: It is possible for collateral to be < treasuryFee because of rounding down for both the share calculation and
        //       the resulting collateral calculated using those shares in `previewAction`, while the treasury fee is calculated
        //       based on the initial equity amount rounded up. In this case, we set the collateral to 0 and the treasury fee to
        //       the computed collateral amount
        data.treasuryFee = Math.min(data.collateral, data.treasuryFee);
        data.collateral = data.collateral > data.treasuryFee ? data.collateral - data.treasuryFee : 0;

        return data;
    }

    /// @inheritdoc ILeverageManager
    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (ActionData memory actionData)
    {
        ActionData memory depositData = previewDeposit(strategy, equityInCollateralAsset);

        if (depositData.shares < minShares) {
            revert SlippageTooHigh(depositData.shares, minShares);
        }

        // Take collateral asset from sender
        IERC20 collateralAsset = getStrategyCollateralAsset(strategy);
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), depositData.collateral);

        // Add collateral to strategy
        _executeLendingAdapterAction(
            strategy, ActionType.AddCollateral, depositData.collateral - depositData.treasuryFee
        );

        // Charge treasury fee
        _chargeTreasuryFee(collateralAsset, depositData.treasuryFee);

        // Borrow and send debt assets to caller
        _executeLendingAdapterAction(strategy, ActionType.Borrow, depositData.debt);
        SafeERC20.safeTransfer(getStrategyDebtAsset(strategy), msg.sender, depositData.debt);

        // Mint shares to user
        strategy.mint(msg.sender, depositData.shares);

        // Emit event and explicit return statement
        emit Deposit(strategy, msg.sender, depositData);
        return depositData;
    }

    /// @inheritdoc ILeverageManager
    function withdraw(IStrategy strategy, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (ActionData memory actionData)
    {
        ActionData memory withdrawData = previewWithdraw(strategy, equityInCollateralAsset);

        if (withdrawData.shares > maxShares) {
            revert SlippageTooHigh(withdrawData.shares, maxShares);
        }

        // Burn shares from user and total supply
        strategy.burn(msg.sender, withdrawData.shares);

        // Take assets from sender and repay the debt
        SafeERC20.safeTransferFrom(getStrategyDebtAsset(strategy), msg.sender, address(this), withdrawData.debt);
        _executeLendingAdapterAction(strategy, ActionType.Repay, withdrawData.debt);

        // Withdraw collateral from lending pool
        _executeLendingAdapterAction(
            strategy, ActionType.RemoveCollateral, withdrawData.collateral + withdrawData.treasuryFee
        );

        // Send collateral assets to sender
        IERC20 collateralAsset = getStrategyCollateralAsset(strategy);
        SafeERC20.safeTransfer(collateralAsset, msg.sender, withdrawData.collateral);

        // Charge treasury fee
        _chargeTreasuryFee(collateralAsset, withdrawData.treasuryFee);

        // Emit event and explicit return statement
        emit Withdraw(strategy, msg.sender, withdrawData);
        return withdrawData;
    }

    /// @inheritdoc ILeverageManager
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
                StrategyState memory state = getStrategyState(strategy);
                strategiesStateBefore[i] = state;

                IRebalanceModule rebalanceAdapter = getStrategyRebalanceModule(strategy);
                if (!rebalanceAdapter.isEligibleForRebalance(strategy, state, msg.sender)) {
                    revert StrategyNotEligibleForRebalance(strategy);
                }
            }

            _executeLendingAdapterAction(strategy, actions[i].actionType, actions[i].amount);
        }

        for (uint256 i = 0; i < actions.length; i++) {
            // Validate the strategy state after rebalancing if it has not been validated yet in a previous iteration of the loop
            if (!_isElementInSlice(actions, actions[i].strategy, i)) {
                IStrategy strategy = actions[i].strategy;
                IRebalanceModule rebalanceAdapter = getStrategyRebalanceModule(strategy);

                if (!rebalanceAdapter.isStateAfterRebalanceValid(strategy, strategiesStateBefore[i])) {
                    revert InvalidStrategyStateAfterRebalance(strategy);
                }
            }
        }

        _transferTokens(tokensOut, address(this), msg.sender);
    }

    /// @notice Function that converts user's equity to shares
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity for
    /// @param equityInCollateralAsset Equity to convert to shares, denominated in collateral asset
    /// @return shares Shares
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(IStrategy strategy, uint256 equityInCollateralAsset)
        internal
        view
        returns (uint256 shares)
    {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        return Math.mulDiv(
            equityInCollateralAsset,
            strategy.totalSupply() + 10 ** DECIMALS_OFFSET,
            lendingAdapter.getEquityInCollateralAsset() + 1,
            Math.Rounding.Floor
        );
    }

    /// @notice Previews parameters related to a deposit action
    /// @param strategy Strategy to preview deposit for
    /// @param equityInCollateralAsset Amount of equity to add or withdraw, denominated in collateral asset
    /// @param action Type of the action to preview, can be Deposit or Withdraw
    /// @return data Preview data for the action
    /// @dev If the strategy has zero total supply of shares (so the strategy does not hold any collateral or debt,
    ///      or holds some leftover dust after all shares are redeemed), then the preview will use the target
    ///      collateral ratio for determining how much collateral and debt is required instead of the current collateral ratio.
    /// @dev If action is deposit collateral will be rounded down and debt up, if action is withdraw collateral will be rounded up and debt down
    function _previewAction(IStrategy strategy, uint256 equityInCollateralAsset, ExternalAction action)
        internal
        view
        returns (ActionData memory data)
    {
        (uint256 equityToCover, uint256 equityForShares, uint256 strategyFee, uint256 treasuryFee) =
            _computeEquityFees(strategy, equityInCollateralAsset, action);

        uint256 shares = _convertToShares(strategy, equityForShares);

        (uint256 collateralForStrategy, uint256 debtForStrategy) =
            _computeCollateralAndDebtForAction(strategy, equityToCover, action);

        // The collateral returned by `_computeCollateralAndDebtForAction` can be zero if the amount of equity for the strategy
        // cannot be exchanged for at least 1 strategy share due to rounding down in the exchange rate calculation.
        // The treasury fee returned by `_computeEquityFees` is wrt the equity amount, not the share amount, thus it's possible
        // for it to be non-zero even if the collateral amount is zero. In this case, the treasury fee should be set to 0
        treasuryFee = collateralForStrategy == 0 ? 0 : treasuryFee;

        return ActionData({
            collateral: collateralForStrategy,
            debt: debtForStrategy,
            equity: equityInCollateralAsset,
            shares: shares,
            strategyFee: strategyFee,
            treasuryFee: treasuryFee
        });
    }

    /// @notice Function that computes collateral and debt required by the position held by a strategy for a given action and an amount of equity to add / remove
    /// @param strategy Strategy to compute collateral and debt for
    /// @param equityInCollateralAsset Equity amount in collateral asset
    /// @param action Action to compute collateral and debt for
    /// @return collateral Collateral to add / remove from the strategy
    /// @return debt Debt to borrow / repay to the strategy
    function _computeCollateralAndDebtForAction(
        IStrategy strategy,
        uint256 equityInCollateralAsset,
        ExternalAction action
    ) internal view returns (uint256 collateral, uint256 debt) {
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);
        uint256 totalDebt = lendingAdapter.getDebt();
        uint256 totalShares = strategy.totalSupply();

        Math.Rounding collateralRounding = action == ExternalAction.Deposit ? Math.Rounding.Ceil : Math.Rounding.Floor;
        Math.Rounding debtRounding = action == ExternalAction.Deposit ? Math.Rounding.Floor : Math.Rounding.Ceil;

        uint256 shares = _convertToShares(strategy, equityInCollateralAsset);

        // If action is deposit there might be some dust in collateral but debt can be 0. In that case we should follow target ratio
        bool shouldFollowTargetRatio = totalShares == 0 || (action == ExternalAction.Deposit && totalDebt == 0);
        if (shouldFollowTargetRatio) {
            uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
            collateral = Math.mulDiv(equityInCollateralAsset, targetRatio, targetRatio - BASE_RATIO, collateralRounding);
            debt = lendingAdapter.convertCollateralToDebtAsset(collateral - equityInCollateralAsset);
        } else {
            collateral = Math.mulDiv(lendingAdapter.getCollateral(), shares, totalShares, collateralRounding);
            debt = Math.mulDiv(totalDebt, shares, totalShares, debtRounding);
        }

        return (collateral, debt);
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
