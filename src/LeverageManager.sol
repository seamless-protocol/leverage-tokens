// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManager} from "src/FeeManager.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {
    ActionData,
    ActionType,
    ExternalAction,
    LeverageTokenConfig,
    BaseLeverageTokenConfig,
    RebalanceAction,
    TokenTransfer
} from "src/types/DataTypes.sol";
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";

contract LeverageManager is ILeverageManager, AccessControlUpgradeable, FeeManager, UUPSUpgradeable {
    // Base collateral ratio constant, 1e8 means that collateral / debt ratio is 1:1
    uint256 public constant BASE_RATIO = 1e8;
    uint256 public constant DECIMALS_OFFSET = 0;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct LeverageManagerStorage {
        /// @dev Factory for deploying new leverage tokens
        IBeaconProxyFactory tokenFactory;
        /// @dev Leverage token address => Base config for leverage token
        mapping(ILeverageToken token => BaseLeverageTokenConfig) config;
        /// @dev Lending adapter address => Is lending adapter registered. Multiple leverage tokens can't have same lending adapter
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
    function getLeverageTokenFactory() public view returns (IBeaconProxyFactory factory) {
        return _getLeverageManagerStorage().tokenFactory;
    }

    /// @inheritdoc ILeverageManager
    function getIsLendingAdapterUsed(address lendingAdapter) public view returns (bool isUsed) {
        return _getLeverageManagerStorage().isLendingAdapterUsed[lendingAdapter];
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenCollateralAsset(ILeverageToken token) public view returns (IERC20 collateralAsset) {
        return getLeverageTokenLendingAdapter(token).getCollateralAsset();
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenDebtAsset(ILeverageToken token) public view returns (IERC20 debtAsset) {
        return getLeverageTokenLendingAdapter(token).getDebtAsset();
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenRebalanceModule(ILeverageToken token) public view returns (IRebalanceModule module) {
        return _getLeverageManagerStorage().config[token].rebalanceModule;
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenConfig(ILeverageToken token) external view returns (LeverageTokenConfig memory config) {
        BaseLeverageTokenConfig memory baseConfig = _getLeverageManagerStorage().config[token];
        uint256 depositTokenFee = getLeverageTokenActionFee(token, ExternalAction.Deposit);
        uint256 withdrawTokenFee = getLeverageTokenActionFee(token, ExternalAction.Withdraw);

        return LeverageTokenConfig({
            lendingAdapter: baseConfig.lendingAdapter,
            targetCollateralRatio: baseConfig.targetCollateralRatio,
            rebalanceModule: baseConfig.rebalanceModule,
            depositTokenFee: depositTokenFee,
            withdrawTokenFee: withdrawTokenFee
        });
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenLendingAdapter(ILeverageToken token) public view returns (ILendingAdapter adapter) {
        return _getLeverageManagerStorage().config[token].lendingAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenTargetCollateralRatio(ILeverageToken token)
        public
        view
        returns (uint256 targetCollateralRatio)
    {
        return _getLeverageManagerStorage().config[token].targetCollateralRatio;
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenState(ILeverageToken token) public view returns (LeverageTokenState memory state) {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);

        uint256 collateral = lendingAdapter.getCollateralInDebtAsset();
        uint256 debt = lendingAdapter.getDebt();
        uint256 equity = lendingAdapter.getEquityInDebtAsset();

        uint256 collateralRatio =
            debt > 0 ? Math.mulDiv(collateral, BASE_RATIO, debt, Math.Rounding.Floor) : type(uint256).max;

        return LeverageTokenState({
            collateralInDebtAsset: collateral,
            debt: debt,
            equity: equity,
            collateralRatio: collateralRatio
        });
    }

    /// @inheritdoc ILeverageManager
    function setLeverageTokenFactory(address factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getLeverageManagerStorage().tokenFactory = IBeaconProxyFactory(factory);
        emit LeverageTokenFactorySet(factory);
    }

    /// @inheritdoc ILeverageManager
    function createNewLeverageToken(LeverageTokenConfig calldata tokenConfig, string memory name, string memory symbol)
        external
        returns (ILeverageToken token)
    {
        IBeaconProxyFactory tokenFactory = getLeverageTokenFactory();

        token = ILeverageToken(
            tokenFactory.createProxy(
                abi.encodeWithSelector(LeverageToken.initialize.selector, address(this), name, symbol),
                bytes32(tokenFactory.getProxies().length)
            )
        );

        if (getIsLendingAdapterUsed(address(tokenConfig.lendingAdapter))) {
            revert LendingAdapterAlreadyInUse(address(tokenConfig.lendingAdapter));
        }

        _getLeverageManagerStorage().config[token] = BaseLeverageTokenConfig({
            lendingAdapter: tokenConfig.lendingAdapter,
            rebalanceModule: tokenConfig.rebalanceModule,
            targetCollateralRatio: tokenConfig.targetCollateralRatio
        });
        _getLeverageManagerStorage().isLendingAdapterUsed[address(tokenConfig.lendingAdapter)] = true;
        _setLeverageTokenActionFee(token, ExternalAction.Deposit, tokenConfig.depositTokenFee);
        _setLeverageTokenActionFee(token, ExternalAction.Withdraw, tokenConfig.withdrawTokenFee);

        emit LeverageTokenCreated(
            token,
            tokenConfig.lendingAdapter.getCollateralAsset(),
            tokenConfig.lendingAdapter.getDebtAsset(),
            tokenConfig
        );
        return token;
    }

    /// @inheritdoc ILeverageManager
    function previewDeposit(ILeverageToken token, uint256 equityInCollateralAsset)
        public
        view
        returns (ActionData memory)
    {
        ActionData memory data = _previewAction(token, equityInCollateralAsset, ExternalAction.Deposit);

        // For deposits, the collateral amount returned by the preview is the total collateral required to execute the
        // deposit, so we add the treasury fee to it, since the collateral computed above is wrt the equity amount with
        // the treasury fee subtracted.
        data.collateral += data.treasuryFee;

        return data;
    }

    /// @inheritdoc ILeverageManager
    function previewWithdraw(ILeverageToken token, uint256 equityInCollateralAsset)
        public
        view
        returns (ActionData memory)
    {
        ActionData memory data = _previewAction(token, equityInCollateralAsset, ExternalAction.Withdraw);

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
    function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (ActionData memory actionData)
    {
        ActionData memory depositData = previewDeposit(token, equityInCollateralAsset);

        if (depositData.shares < minShares) {
            revert SlippageTooHigh(depositData.shares, minShares);
        }

        // Take collateral asset from sender
        IERC20 collateralAsset = getLeverageTokenCollateralAsset(token);
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), depositData.collateral);

        // Add collateral to leverage token
        _executeLendingAdapterAction(token, ActionType.AddCollateral, depositData.collateral - depositData.treasuryFee);

        // Charge treasury fee
        _chargeTreasuryFee(collateralAsset, depositData.treasuryFee);

        // Borrow and send debt assets to caller
        _executeLendingAdapterAction(token, ActionType.Borrow, depositData.debt);
        SafeERC20.safeTransfer(getLeverageTokenDebtAsset(token), msg.sender, depositData.debt);

        // Mint shares to user
        token.mint(msg.sender, depositData.shares);

        // Emit event and explicit return statement
        emit Deposit(token, msg.sender, depositData);
        return depositData;
    }

    /// @inheritdoc ILeverageManager
    function withdraw(ILeverageToken token, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (ActionData memory actionData)
    {
        ActionData memory withdrawData = previewWithdraw(token, equityInCollateralAsset);

        if (withdrawData.shares > maxShares) {
            revert SlippageTooHigh(withdrawData.shares, maxShares);
        }

        // Burn shares from user and total supply
        token.burn(msg.sender, withdrawData.shares);

        // Take assets from sender and repay the debt
        SafeERC20.safeTransferFrom(getLeverageTokenDebtAsset(token), msg.sender, address(this), withdrawData.debt);
        _executeLendingAdapterAction(token, ActionType.Repay, withdrawData.debt);

        // Withdraw collateral from lending pool
        _executeLendingAdapterAction(
            token, ActionType.RemoveCollateral, withdrawData.collateral + withdrawData.treasuryFee
        );

        // Send collateral assets to sender
        IERC20 collateralAsset = getLeverageTokenCollateralAsset(token);
        SafeERC20.safeTransfer(collateralAsset, msg.sender, withdrawData.collateral);

        // Charge treasury fee
        _chargeTreasuryFee(collateralAsset, withdrawData.treasuryFee);

        // Emit event and explicit return statement
        emit Withdraw(token, msg.sender, withdrawData);
        return withdrawData;
    }

    /// @inheritdoc ILeverageManager
    function rebalance(
        RebalanceAction[] calldata actions,
        TokenTransfer[] calldata tokensIn,
        TokenTransfer[] calldata tokensOut
    ) external {
        _transferTokens(tokensIn, msg.sender, address(this));

        LeverageTokenState[] memory leverageTokensStateBefore = new LeverageTokenState[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            ILeverageToken leverageToken = actions[i].leverageToken;

            // Check if the leverage token is eligible for rebalance if it has not been checked yet in a previous iteration of the loop
            if (!_isElementInSlice(actions, leverageToken, i)) {
                LeverageTokenState memory state = getLeverageTokenState(leverageToken);
                leverageTokensStateBefore[i] = state;

                IRebalanceModule rebalanceModule = getLeverageTokenRebalanceModule(leverageToken);
                if (!rebalanceModule.isEligibleForRebalance(leverageToken, state, msg.sender)) {
                    revert LeverageTokenNotEligibleForRebalance(leverageToken);
                }
            }

            _executeLendingAdapterAction(leverageToken, actions[i].actionType, actions[i].amount);
        }

        for (uint256 i = 0; i < actions.length; i++) {
            // Validate the leverage token state after rebalancing if it has not been validated yet in a previous iteration of the loop
            if (!_isElementInSlice(actions, actions[i].leverageToken, i)) {
                ILeverageToken leverageToken = actions[i].leverageToken;
                IRebalanceModule rebalanceModule = getLeverageTokenRebalanceModule(leverageToken);

                if (!rebalanceModule.isStateAfterRebalanceValid(leverageToken, leverageTokensStateBefore[i])) {
                    revert InvalidLeverageTokenStateAfterRebalance(leverageToken);
                }
            }
        }

        _transferTokens(tokensOut, address(this), msg.sender);
    }

    /// @notice Function that converts user's equity to shares
    /// @notice Function uses OZ formula for calculating shares
    /// @param token Leverage token to convert equity for
    /// @param equityInCollateralAsset Equity to convert to shares, denominated in collateral asset
    /// @return shares Shares
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(ILeverageToken token, uint256 equityInCollateralAsset)
        internal
        view
        returns (uint256 shares)
    {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);

        return Math.mulDiv(
            equityInCollateralAsset,
            token.totalSupply() + 10 ** DECIMALS_OFFSET,
            lendingAdapter.getEquityInCollateralAsset() + 1,
            Math.Rounding.Floor
        );
    }

    /// @notice Previews parameters related to a deposit action
    /// @param token Leverage token to preview deposit for
    /// @param equityInCollateralAsset Amount of equity to add or withdraw, denominated in collateral asset
    /// @param action Type of the action to preview, can be Deposit or Withdraw
    /// @return data Preview data for the action
    /// @dev If the leverage token has zero total supply of shares (so the leverage token does not hold any collateral or debt,
    ///      or holds some leftover dust after all shares are redeemed), then the preview will use the target
    ///      collateral ratio for determining how much collateral and debt is required instead of the current collateral ratio.
    /// @dev If action is deposit collateral will be rounded down and debt up, if action is withdraw collateral will be rounded up and debt down
    function _previewAction(ILeverageToken token, uint256 equityInCollateralAsset, ExternalAction action)
        internal
        view
        returns (ActionData memory data)
    {
        (uint256 equityToCover, uint256 equityForShares, uint256 tokenFee, uint256 treasuryFee) =
            _computeEquityFees(token, equityInCollateralAsset, action);

        uint256 shares = _convertToShares(token, equityForShares);

        (uint256 collateral, uint256 debt) = _computeCollateralAndDebtForAction(token, equityToCover, action);

        // The collateral returned by `_computeCollateralAndDebtForAction` can be zero if the amount of equity for the leverage token
        // cannot be exchanged for at least 1 leverage token share due to rounding down in the exchange rate calculation.
        // The treasury fee returned by `_computeEquityFees` is wrt the equity amount, not the share amount, thus it's possible
        // for it to be non-zero even if the collateral amount is zero. In this case, the treasury fee should be set to 0
        treasuryFee = collateral == 0 ? 0 : treasuryFee;

        return ActionData({
            collateral: collateral,
            debt: debt,
            equity: equityInCollateralAsset,
            shares: shares,
            tokenFee: tokenFee,
            treasuryFee: treasuryFee
        });
    }

    /// @notice Function that computes collateral and debt required by the position held by a leverage token for a given action and an amount of equity to add / remove
    /// @param token Leverage token to compute collateral and debt for
    /// @param equityInCollateralAsset Equity amount in collateral asset
    /// @param action Action to compute collateral and debt for
    /// @return collateral Collateral to add / remove from the leverage token
    /// @return debt Debt to borrow / repay to the leverage token
    function _computeCollateralAndDebtForAction(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        ExternalAction action
    ) internal view returns (uint256 collateral, uint256 debt) {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);
        uint256 totalDebt = lendingAdapter.getDebt();
        uint256 totalShares = token.totalSupply();

        Math.Rounding collateralRounding = action == ExternalAction.Deposit ? Math.Rounding.Ceil : Math.Rounding.Floor;
        Math.Rounding debtRounding = action == ExternalAction.Deposit ? Math.Rounding.Floor : Math.Rounding.Ceil;

        uint256 shares = _convertToShares(token, equityInCollateralAsset);

        // If action is deposit there might be some dust in collateral but debt can be 0. In that case we should follow target ratio
        bool shouldFollowTargetRatio = totalShares == 0 || (action == ExternalAction.Deposit && totalDebt == 0);

        if (shouldFollowTargetRatio) {
            uint256 targetRatio = getLeverageTokenTargetCollateralRatio(token);
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
    /// @param token Element to search for
    /// @param untilIndex Search until this specific index
    /// @dev This function is used to check if we already stored the state of the leverage token before rebalance.
    ///      This function is used to check if leverage token state has been already validated after rebalance
    function _isElementInSlice(RebalanceAction[] calldata actions, ILeverageToken token, uint256 untilIndex)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < untilIndex; i++) {
            if (address(actions[i].leverageToken) == address(token)) {
                return true;
            }
        }

        return false;
    }

    /// @notice Executes action on lending adapter from specific leverage token
    /// @param token Leverage token to execute action on
    /// @param actionType Type of the action to execute
    /// @param amount Amount to execute action with
    function _executeLendingAdapterAction(ILeverageToken token, ActionType actionType, uint256 amount) internal {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);

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
