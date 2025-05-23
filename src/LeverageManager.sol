// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardTransientUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Internal imports
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
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
    RebalanceAction
} from "src/types/DataTypes.sol";

/**
 * @dev The LeverageManager contract is an upgradeable core contract that is responsible for managing the creation of LeverageTokens.
 * It also acts as an entry point for users to mint and redeem LeverageTokens (shares), and for
 * rebalancers to rebalance LeverageTokens.
 *
 * LeverageTokens are ERC20 tokens that are akin to shares in an ERC-4626 vault - they represent a claim on the equity held by
 * the LeverageToken. They can be created on this contract by calling `createNewLeverageToken`, and their configuration on the
 * LeverageManager is immutable.
 * Note: Although the LeverageToken configuration saved on the LeverageManager is immutable, the configured LendingAdapter and
 *       RebalanceAdapter for the LeverageToken may be upgradeable contracts.
 *
 * The LeverageManager also inherits the `FeeManager` contract, which is used to manage LeverageToken fees (which accrue to
 * the share value of the LeverageToken) and the treasury fees.
 *
 * For mints of LeverageTokens (shares), the collateral and debt required is calculated by using the LeverageToken's
 * current collateral ratio. As such, the collateral ratio after a mint must be equal to the collateral ratio before a
 * mint, within some rounding error.
 *
 * [CAUTION]
 * ====
 * - LeverageTokens are susceptible to inflation attacks like ERC-4626 vaults:
 *   "In empty (or nearly empty) ERC-4626 vaults, mints are at high risk of being stolen through frontrunning
 *   with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
 *   attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
 *   mint of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Redeems may
 *   similarly be affected by slippage. Users can protect against this attack as well as unexpected slippage in general by
 *   verifying the amount received is as expected, using a wrapper that performs these checks such as
 *   https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router]."
 *
 *   As such it is highly recommended that LeverageToken creators make an initial mint of a non-trivial amount of equity.
 *   It is also recommended to use a router that performs slippage checks when minting and redeeming.
 *
 * - LeverageToken creation is permissionless and can be configured with arbitrary lending adapters, rebalance adapters, and
 *   underlying collateral and debt assets. As such, the adapters and tokens used by a LeverageToken are part of the risk
 *   profile of the LeverageToken, and should be carefully considered by users before using a LeverageToken.
 *
 * - LeverageTokens can be configured with arbitrary lending adapters, thus LeverageTokens are directly affected by the
 *   specific mechanisms of the underlying lending market that their lending adapter integrates with. As mentioned above,
 *   it is highly recommended that users research and understand the lending adapter used by the LeverageToken they are
 *   considering using. Some examples:
 *   - Morpho: Users should be aware that Morpho market creation is permissionless, and that the price oracle used by
 *     by the market may be manipulatable.
 *   - Aave v3: Allows rehypothecation of collateral, which may lead to reverts when trying to remove collateral from the
 *     market during redeems and rebalances.
 */
contract LeverageManager is
    ILeverageManager,
    AccessControlUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    FeeManager,
    UUPSUpgradeable
{
    // Base collateral ratio constant, 1e18 means that collateral / debt ratio is 1:1
    uint256 public constant BASE_RATIO = 1e18;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct LeverageManagerStorage {
        /// @dev Factory for deploying new LeverageTokens
        IBeaconProxyFactory tokenFactory;
        /// @dev LeverageToken address => Base config for LeverageToken
        mapping(ILeverageToken token => BaseLeverageTokenConfig) config;
    }

    function _getLeverageManagerStorage() internal pure returns (LeverageManagerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600
        }
    }

    function initialize(address initialAdmin, address treasury, IBeaconProxyFactory leverageTokenFactory)
        external
        initializer
    {
        __FeeManager_init(initialAdmin, treasury);
        __ReentrancyGuardTransient_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _getLeverageManagerStorage().tokenFactory = leverageTokenFactory;
        emit LeverageManagerInitialized(leverageTokenFactory);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ILeverageManager
    function getLeverageTokenFactory() public view returns (IBeaconProxyFactory factory) {
        return _getLeverageManagerStorage().tokenFactory;
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
    function getLeverageTokenRebalanceAdapter(ILeverageToken token)
        public
        view
        returns (IRebalanceAdapterBase module)
    {
        return _getLeverageManagerStorage().config[token].rebalanceAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenConfig(ILeverageToken token) external view returns (LeverageTokenConfig memory config) {
        BaseLeverageTokenConfig memory baseConfig = _getLeverageManagerStorage().config[token];
        uint256 mintTokenFee = getLeverageTokenActionFee(token, ExternalAction.Mint);
        uint256 redeemTokenFee = getLeverageTokenActionFee(token, ExternalAction.Redeem);

        return LeverageTokenConfig({
            lendingAdapter: baseConfig.lendingAdapter,
            rebalanceAdapter: baseConfig.rebalanceAdapter,
            mintTokenFee: mintTokenFee,
            redeemTokenFee: redeemTokenFee
        });
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenLendingAdapter(ILeverageToken token) public view returns (ILendingAdapter adapter) {
        return _getLeverageManagerStorage().config[token].lendingAdapter;
    }

    /// @inheritdoc ILeverageManager
    function getLeverageTokenInitialCollateralRatio(ILeverageToken token) public view returns (uint256 ratio) {
        return getLeverageTokenRebalanceAdapter(token).getLeverageTokenInitialCollateralRatio(token);
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
    function createNewLeverageToken(LeverageTokenConfig calldata tokenConfig, string memory name, string memory symbol)
        external
        nonReentrant
        returns (ILeverageToken token)
    {
        IBeaconProxyFactory tokenFactory = getLeverageTokenFactory();

        // slither-disable-next-line reentrancy-events
        token = ILeverageToken(
            tokenFactory.createProxy(
                abi.encodeWithSelector(LeverageToken.initialize.selector, address(this), name, symbol),
                bytes32(tokenFactory.numProxies())
            )
        );

        _getLeverageManagerStorage().config[token] = BaseLeverageTokenConfig({
            lendingAdapter: tokenConfig.lendingAdapter,
            rebalanceAdapter: tokenConfig.rebalanceAdapter
        });
        _setLeverageTokenActionFee(token, ExternalAction.Mint, tokenConfig.mintTokenFee);
        _setLeverageTokenActionFee(token, ExternalAction.Redeem, tokenConfig.redeemTokenFee);
        _setNewLeverageTokenManagementFee(token);

        tokenConfig.lendingAdapter.postLeverageTokenCreation(msg.sender, address(token));
        tokenConfig.rebalanceAdapter.postLeverageTokenCreation(msg.sender, address(token));

        emit LeverageTokenCreated(
            token,
            tokenConfig.lendingAdapter.getCollateralAsset(),
            tokenConfig.lendingAdapter.getDebtAsset(),
            tokenConfig
        );
        return token;
    }

    /// @inheritdoc ILeverageManager
    function previewMint(ILeverageToken token, uint256 equityInCollateralAsset)
        public
        view
        returns (ActionData memory)
    {
        return _previewAction(token, equityInCollateralAsset, ExternalAction.Mint);
    }

    /// @inheritdoc ILeverageManager
    function previewRedeem(ILeverageToken token, uint256 equityInCollateralAsset)
        public
        view
        returns (ActionData memory)
    {
        return _previewAction(token, equityInCollateralAsset, ExternalAction.Redeem);
    }

    /// @inheritdoc ILeverageManager
    function mint(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares)
        external
        nonReentrant
        returns (ActionData memory actionData)
    {
        // Management fee is calculated from the total supply of the LeverageToken, so we need to claim it first
        // before total supply is updated due to the mint
        chargeManagementFee(token);

        ActionData memory mintData = previewMint(token, equityInCollateralAsset);

        // slither-disable-next-line timestamp
        if (mintData.shares < minShares) {
            revert SlippageTooHigh(mintData.shares, minShares);
        }

        // Take collateral asset from sender
        IERC20 collateralAsset = getLeverageTokenCollateralAsset(token);
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), mintData.collateral);

        // Add collateral to LeverageToken
        _executeLendingAdapterAction(token, ActionType.AddCollateral, mintData.collateral);

        // Borrow and send debt assets to caller
        _executeLendingAdapterAction(token, ActionType.Borrow, mintData.debt);
        SafeERC20.safeTransfer(getLeverageTokenDebtAsset(token), msg.sender, mintData.debt);

        // Charge treasury fee
        _chargeTreasuryFee(token, mintData.treasuryFee);

        // Mint shares to user
        // slither-disable-next-line reentrancy-events
        token.mint(msg.sender, mintData.shares);

        // Emit event and explicit return statement
        emit Mint(token, msg.sender, mintData);
        return mintData;
    }

    /// @inheritdoc ILeverageManager
    function redeem(ILeverageToken token, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        nonReentrant
        returns (ActionData memory actionData)
    {
        // Management fee is calculated from the total supply of the LeverageToken, so we need to claim it first
        // before total supply is updated due to the redeem
        chargeManagementFee(token);

        ActionData memory redeemData = previewRedeem(token, equityInCollateralAsset);

        // slither-disable-next-line timestamp
        if (redeemData.shares > maxShares) {
            revert SlippageTooHigh(redeemData.shares, maxShares);
        }

        // Burn shares from user and total supply
        token.burn(msg.sender, redeemData.shares);

        // Mint shares to treasury for the treasury action fee
        _chargeTreasuryFee(token, redeemData.treasuryFee);

        // Take assets from sender and repay the debt
        SafeERC20.safeTransferFrom(getLeverageTokenDebtAsset(token), msg.sender, address(this), redeemData.debt);
        _executeLendingAdapterAction(token, ActionType.Repay, redeemData.debt);

        // Remove collateral from lending pool
        _executeLendingAdapterAction(token, ActionType.RemoveCollateral, redeemData.collateral);

        // Send collateral assets to sender
        IERC20 collateralAsset = getLeverageTokenCollateralAsset(token);
        SafeERC20.safeTransfer(collateralAsset, msg.sender, redeemData.collateral);

        // Emit event and explicit return statement
        emit Redeem(token, msg.sender, redeemData);
        return redeemData;
    }

    /// @inheritdoc ILeverageManager
    function rebalance(
        ILeverageToken leverageToken,
        RebalanceAction[] calldata actions,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external nonReentrant {
        _transferTokens(tokenIn, msg.sender, address(this), amountIn);

        // Check if the LeverageToken is eligible for rebalance
        LeverageTokenState memory stateBefore = getLeverageTokenState(leverageToken);

        IRebalanceAdapterBase rebalanceAdapter = getLeverageTokenRebalanceAdapter(leverageToken);
        if (!rebalanceAdapter.isEligibleForRebalance(leverageToken, stateBefore, msg.sender)) {
            revert LeverageTokenNotEligibleForRebalance();
        }

        for (uint256 i = 0; i < actions.length; i++) {
            _executeLendingAdapterAction(leverageToken, actions[i].actionType, actions[i].amount);
        }

        // Validate the LeverageToken state after rebalancing
        if (!rebalanceAdapter.isStateAfterRebalanceValid(leverageToken, stateBefore)) {
            revert InvalidLeverageTokenStateAfterRebalance(leverageToken);
        }

        _transferTokens(tokenOut, address(this), msg.sender, amountOut);
    }

    /// @notice Function that converts user's equity to shares
    /// @notice Function uses OZ formula for calculating shares
    /// @param token LeverageToken to convert equity for
    /// @param equityInCollateralAsset Equity to convert to shares, denominated in collateral asset
    /// @param action Action to convert equity for
    /// @return shares Shares
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(ILeverageToken token, uint256 equityInCollateralAsset, ExternalAction action)
        internal
        view
        returns (uint256 shares)
    {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);

        uint256 totalSupply = _getFeeAdjustedTotalSupply(token);
        uint256 totalEquityInCollateralAsset = lendingAdapter.getEquityInCollateralAsset();

        // If leverage token is empty we mint it in 1:1 ratio with collateral asset but we align it on 18 decimals always
        // slither-disable-next-line incorrect-equality,timestamp
        if (totalSupply == 0 || totalEquityInCollateralAsset == 0) {
            uint256 leverageTokenDecimals = IERC20Metadata(address(token)).decimals();
            uint256 collateralDecimals = IERC20Metadata(address(lendingAdapter.getCollateralAsset())).decimals();

            // If collateral asset has more decimals than leverage token, we scale down the equity in collateral asset
            // Otherwise we scale up the equity in collateral asset
            if (collateralDecimals > leverageTokenDecimals) {
                uint256 scalingFactor = 10 ** (collateralDecimals - leverageTokenDecimals);
                return equityInCollateralAsset / scalingFactor;
            } else {
                uint256 scalingFactor = 10 ** (leverageTokenDecimals - collateralDecimals);
                return equityInCollateralAsset * scalingFactor;
            }
        }

        Math.Rounding rounding = action == ExternalAction.Mint ? Math.Rounding.Floor : Math.Rounding.Ceil;
        return Math.mulDiv(equityInCollateralAsset, totalSupply, totalEquityInCollateralAsset, rounding);
    }

    /// @notice Previews parameters related to a mint action
    /// @param token LeverageToken to preview mint for
    /// @param equityInCollateralAsset Amount of equity to give or receive, denominated in collateral asset
    /// @param action Type of the action to preview, can be Mint or Redeem
    /// @return data Preview data for the action
    /// @dev If the LeverageToken has zero total supply of shares (so the LeverageToken does not hold any collateral or debt,
    ///      or holds some leftover dust after all shares are redeemed), then the preview will use the target
    ///      collateral ratio for determining how much collateral and debt is required instead of the current collateral ratio.
    /// @dev If action is mint collateral will be rounded down and debt up, if action is redeem collateral will be rounded up and debt down
    function _previewAction(ILeverageToken token, uint256 equityInCollateralAsset, ExternalAction action)
        internal
        view
        returns (ActionData memory data)
    {
        (uint256 collateral, uint256 debt) = _computeCollateralAndDebtForAction(token, equityInCollateralAsset, action);

        (uint256 equityForShares, uint256 tokenFee) = _computeTokenFee(token, equityInCollateralAsset, action);
        uint256 shares = _convertToShares(token, equityForShares, action);
        uint256 treasuryFee = _computeTreasuryFee(action, shares);

        // On mints, some of the minted shares are for the treasury fee
        // On redeems, additional shares are taken from the user to cover the treasury fee
        uint256 userSharesDelta = action == ExternalAction.Mint ? shares - treasuryFee : shares + treasuryFee;

        return ActionData({
            collateral: collateral,
            debt: debt,
            equity: equityInCollateralAsset,
            shares: userSharesDelta,
            tokenFee: tokenFee,
            treasuryFee: treasuryFee
        });
    }

    /// @notice Function that computes collateral and debt required by the position held by a LeverageToken for a given action and an amount of equity to add / remove
    /// @param token LeverageToken to compute collateral and debt for
    /// @param equityInCollateralAsset Equity amount in collateral asset
    /// @param action Action to compute collateral and debt for
    /// @return collateral Collateral to add / remove from the LeverageToken
    /// @return debt Debt to borrow / repay to the LeverageToken
    function _computeCollateralAndDebtForAction(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        ExternalAction action
    ) internal view returns (uint256 collateral, uint256 debt) {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);
        uint256 totalDebt = lendingAdapter.getDebt();
        uint256 totalShares = _getFeeAdjustedTotalSupply(token);

        Math.Rounding collateralRounding = action == ExternalAction.Mint ? Math.Rounding.Ceil : Math.Rounding.Floor;
        Math.Rounding debtRounding = action == ExternalAction.Mint ? Math.Rounding.Floor : Math.Rounding.Ceil;

        uint256 shares = _convertToShares(token, equityInCollateralAsset, action);

        // If action is mint there might be some dust in collateral but debt can be 0. In that case we should follow target ratio
        // slither-disable-next-line incorrect-equality,timestamp
        bool shouldFollowInitialRatio = totalShares == 0 || (action == ExternalAction.Mint && totalDebt == 0);

        if (shouldFollowInitialRatio) {
            uint256 initialRatio = getLeverageTokenInitialCollateralRatio(token);
            collateral =
                Math.mulDiv(equityInCollateralAsset, initialRatio, initialRatio - BASE_RATIO, collateralRounding);
            debt = lendingAdapter.convertCollateralToDebtAsset(collateral - equityInCollateralAsset);
        } else {
            collateral = Math.mulDiv(lendingAdapter.getCollateral(), shares, totalShares, collateralRounding);
            debt = Math.mulDiv(totalDebt, shares, totalShares, debtRounding);
        }

        return (collateral, debt);
    }

    /// @notice Executes actions on the LendingAdapter for a specific LeverageToken
    /// @param token LeverageToken to execute action for
    /// @param actionType Type of the action to execute
    /// @param amount Amount to execute action with
    function _executeLendingAdapterAction(ILeverageToken token, ActionType actionType, uint256 amount) internal {
        ILendingAdapter lendingAdapter = getLeverageTokenLendingAdapter(token);

        if (actionType == ActionType.AddCollateral) {
            IERC20 collateralAsset = lendingAdapter.getCollateralAsset();
            // slither-disable-next-line reentrancy-events
            SafeERC20.forceApprove(collateralAsset, address(lendingAdapter), amount);
            // slither-disable-next-line reentrancy-events
            lendingAdapter.addCollateral(amount);
        } else if (actionType == ActionType.RemoveCollateral) {
            // slither-disable-next-line reentrancy-events
            lendingAdapter.removeCollateral(amount);
        } else if (actionType == ActionType.Borrow) {
            // slither-disable-next-line reentrancy-events
            lendingAdapter.borrow(amount);
        } else if (actionType == ActionType.Repay) {
            IERC20 debtAsset = lendingAdapter.getDebtAsset();
            // slither-disable-next-line reentrancy-events
            SafeERC20.forceApprove(debtAsset, address(lendingAdapter), amount);
            // slither-disable-next-line reentrancy-events
            lendingAdapter.repay(amount);
        }
    }

    /// @notice Helper function for transferring tokens, or no-op if token is 0 address
    /// @param token Token to transfer
    /// @param from Address to transfer tokens from
    /// @param to Address to transfer tokens to
    /// @dev If from address is this smart contract it will use the regular transfer function otherwise it will use transferFrom
    function _transferTokens(IERC20 token, address from, address to, uint256 amount) internal {
        if (address(token) == address(0)) {
            return;
        }

        if (from == address(this)) {
            SafeERC20.safeTransfer(token, to, amount);
        } else {
            SafeERC20.safeTransferFrom(token, from, to, amount);
        }
    }
}
