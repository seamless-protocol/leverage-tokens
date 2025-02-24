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
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {FeeManager} from "src/FeeManager.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {CollateralRatios, StrategyState} from "src/types/DataTypes.sol";
import {Strategy} from "src/Strategy.sol";
import {RebalanceAction, TokenTransfer, ActionType, ExternalAction, StrategyState} from "src/types/DataTypes.sol";

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
    function getStrategyRebalanceRewardDistributor(IStrategy strategy)
        public
        view
        returns (IRebalanceRewardDistributor distributor)
    {
        return Storage.layout().config[strategy].rebalanceRewardDistributor;
    }

    function getStrategyRebalanceWhitelist(IStrategy strategy) public view returns (IRebalanceWhitelist whitelist) {
        return Storage.layout().config[strategy].rebalanceWhitelist;
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

        Storage.layout().config[strategy] = strategyConfig;

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
        returns (uint256 collateralToAdd, uint256 debtToBorrow, uint256 sharesAfterFee, uint256 sharesFee)
    {
        return _previewAction(strategy, equityInCollateralAsset, ExternalAction.Deposit);
    }

    /// @inheritdoc ILeverageManager
    function previewWithdraw(IStrategy strategy, uint256 equityInCollateralAsset)
        public
        view
        returns (uint256 collateralToRemove, uint256 debtToRepay, uint256 sharesAfterFee, uint256 sharesFee)
    {
        return _previewAction(strategy, equityInCollateralAsset, ExternalAction.Withdraw);
    }

    /// @inheritdoc ILeverageManager
    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 sharesAfterFee, uint256 sharesFee) =
            previewDeposit(strategy, equityInCollateralAsset);

        if (sharesAfterFee < minShares) {
            revert SlippageTooHigh(sharesAfterFee, minShares);
        }

        // Take asset from sender and supply it as collateral
        SafeERC20.safeTransferFrom(getStrategyCollateralAsset(strategy), msg.sender, address(this), collateralToAdd);
        _executeLendingAdapterAction(strategy, ActionType.AddCollateral, collateralToAdd);

        // Borrow and send debt assets to caller
        _executeLendingAdapterAction(strategy, ActionType.Borrow, debtToBorrow);
        SafeERC20.safeTransfer(getStrategyDebtAsset(strategy), msg.sender, debtToBorrow);

        // Mint shares to user
        strategy.mint(msg.sender, sharesAfterFee);

        // Emit event and explicit return statement
        emit Deposit(
            strategy, msg.sender, collateralToAdd, debtToBorrow, equityInCollateralAsset, sharesAfterFee, sharesFee
        );
        return (collateralToAdd, debtToBorrow, sharesAfterFee, sharesFee);
    }

    /// @inheritdoc ILeverageManager
    function withdraw(IStrategy strategy, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 collateral, uint256 debt, uint256 sharesAfterFee, uint256 sharesFee) =
            previewWithdraw(strategy, equityInCollateralAsset);

        if (sharesAfterFee > maxShares) {
            revert SlippageTooHigh(sharesAfterFee, maxShares);
        }

        // Burn shares from user and total supply
        strategy.burn(msg.sender, sharesAfterFee);

        // Take assets from sender and repay the debt
        SafeERC20.safeTransferFrom(getStrategyDebtAsset(strategy), msg.sender, address(this), debt);
        _executeLendingAdapterAction(strategy, ActionType.Repay, debt);

        // Withdraw from lending pool and send assets to user
        _executeLendingAdapterAction(strategy, ActionType.RemoveCollateral, collateral);
        SafeERC20.safeTransfer(getStrategyCollateralAsset(strategy), msg.sender, collateral);

        // Emit event and explicit return statement
        emit Withdraw(strategy, msg.sender, collateral, debt, equityInCollateralAsset, sharesAfterFee, sharesFee);
        return (collateral, debt, sharesAfterFee, sharesFee);
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
                StrategyState memory state = _getStrategyState(strategy);
                strategiesStateBefore[i] = state;

                _validateIsAuthorizedToRebalance(strategy);
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

    /// @notice Validates if caller is allowed to rebalance strategy
    /// @param strategy Strategy to validate caller for
    /// @dev Caller is not allowed to rebalance strategy if they are not whitelisted in the strategy's rebalance whitelist module
    function _validateIsAuthorizedToRebalance(IStrategy strategy) internal view {
        IRebalanceWhitelist whitelist = getStrategyRebalanceWhitelist(strategy);

        if (address(whitelist) != address(0) && !whitelist.isAllowedToRebalance(address(strategy), msg.sender)) {
            revert NotRebalancer(strategy, msg.sender);
        }
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
        _validateCollateralRatioAfterRebalance(strategy, stateBefore.collateralRatio, stateAfter.collateralRatio);
    }

    /// @notice Validates collateral ratio after rebalance
    /// @param strategy Strategy to validate ratio for
    /// @param collateralRatioBefore Collateral ratio before rebalance
    /// @param collateralRatioAfter Collateral ratio after rebalance
    /// @dev Collateral ratio after rebalance needs to be closer to target ratio than before rebalance. Also both collateral ratios
    ///      need to be on the same side. This means if strategy was overexposed before rebalance it can not be underexposed not and vice verse.
    function _validateCollateralRatioAfterRebalance(
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

        uint256 reward = getStrategyRebalanceRewardDistributor(strategy).computeRebalanceReward(
            address(strategy), stateBefore, stateAfter
        );

        if (equityAfter < equityBefore - reward) {
            revert EquityLossTooBig();
        }
    }

    /// @notice Function that converts user's equity to shares
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity for
    /// @param equityInCollateralAsset Equity to convert to shares, denominated in collateral asset
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

    /// @notice Returns all data required to describe current strategy state - collateral, debt, equity and collateral ratio
    /// @param strategy Strategy to query state for
    function _getStrategyState(IStrategy strategy) internal view returns (StrategyState memory) {
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

    /// @notice Previews parameters related to a deposit action
    /// @param strategy Strategy to preview deposit for
    /// @param equityInCollateralAsset Amount of equity to add or withdraw, denominated in collateral asset
    /// @param action Type of the action to preview, can be Deposit or Withdraw
    /// @return collateral Amount of collateral to add or withdraw
    /// @return debt Amount of debt to borrow or repay
    /// @return sharesAfterFee Amount of shares to mint or burn after fee
    /// @return sharesFee Amount of fee to pay for the action
    /// @dev If the strategy has zero total supply of shares (so the strategy does not hold any collateral or debt,
    ///      or holds some leftover dust after all shares are redeemed), then the preview will use the target
    ///      collateral ratio for determining how much collateral and debt is required instead of the current collateral ratio.
    /// @dev If action is deposit collateral will be rounded down and debt up, if action is withdraw collateral will be rounded up and debt down
    function _previewAction(IStrategy strategy, uint256 equityInCollateralAsset, ExternalAction action)
        internal
        view
        returns (uint256 collateral, uint256 debt, uint256 sharesAfterFee, uint256 sharesFee)
    {
        // Cache
        ILendingAdapter lendingAdapter = getStrategyLendingAdapter(strategy);

        // Convert equity and charge fee
        uint256 sharesBeforeFee = _convertToShares(strategy, equityInCollateralAsset);
        (sharesAfterFee, sharesFee) = _computeFeeAdjustedShares(strategy, sharesBeforeFee, action);

        uint256 totalShares = strategy.totalSupply();

        Math.Rounding collateralRounding = action == ExternalAction.Deposit ? Math.Rounding.Ceil : Math.Rounding.Floor;
        Math.Rounding debtRounding = action == ExternalAction.Deposit ? Math.Rounding.Floor : Math.Rounding.Ceil;

        if (totalShares == 0) {
            uint256 targetRatio = getStrategyTargetCollateralRatio(strategy);
            collateral = Math.mulDiv(equityInCollateralAsset, targetRatio, targetRatio - BASE_RATIO, collateralRounding);
            debt = lendingAdapter.convertCollateralToDebtAsset(collateral - equityInCollateralAsset);
        } else {
            collateral = Math.mulDiv(lendingAdapter.getCollateral(), sharesBeforeFee, totalShares, collateralRounding);
            debt = Math.mulDiv(lendingAdapter.getDebt(), sharesBeforeFee, totalShares, debtRounding);
        }

        return (collateral, debt, sharesAfterFee, sharesFee);
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
