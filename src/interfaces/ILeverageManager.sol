// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageToken} from "./ILeverageToken.sol";
import {IFeeManager} from "./IFeeManager.sol";
import {IBeaconProxyFactory} from "./IBeaconProxyFactory.sol";
import {ILendingAdapter} from "./ILendingAdapter.sol";
import {
    ActionData,
    LeverageTokenState,
    RebalanceAction,
    TokenTransfer,
    LeverageTokenConfig
} from "src/types/DataTypes.sol";
import {IRebalanceAdapter} from "./IRebalanceAdapter.sol";

interface ILeverageManager is IFeeManager {
    /// @notice Error thrown when someone tries to create leverage token with lending adapter that already exists
    error LendingAdapterAlreadyInUse(address adapter);

    /// @notice Error thrown when someone tries to set zero address for collateral or debt asset when creating leverage token
    error InvalidLeverageTokenAssets();

    /// @notice Error thrown when collateral ratios are invalid
    error InvalidCollateralRatios();

    /// @notice Error thrown when slippage is too high during mint/redeem
    error SlippageTooHigh(uint256 actual, uint256 expected);

    /// @notice Error thrown when caller is whitelisted for rebalance action
    error NotRebalancer(ILeverageToken token, address caller);

    /// @notice Error thrown when leverage token is not eligible for rebalance
    error LeverageTokenNotEligibleForRebalance(ILeverageToken token);

    /// @notice Error thrown when leverage token state after rebalance is invalid
    error InvalidLeverageTokenStateAfterRebalance(ILeverageToken token);

    /// @notice Event emitted when leverage token factory is set
    event LeverageTokenFactorySet(address factory);

    /// @notice Event emitted when new leverage token is created
    event LeverageTokenCreated(
        ILeverageToken indexed token, IERC20 collateralAsset, IERC20 debtAsset, LeverageTokenConfig config
    );

    /// @notice Event emitted when user deposits assets into leverage token
    event Deposit(ILeverageToken indexed token, address indexed sender, ActionData actionData);

    /// @notice Event emitted when user withdraws assets from leverage token
    event Withdraw(ILeverageToken indexed token, address indexed sender, ActionData actionData);

    /// @notice Returns factory for creating new leverage tokens
    /// @return factory Factory for creating new leverage tokens
    function getLeverageTokenFactory() external view returns (IBeaconProxyFactory factory);

    /// @notice Returns if lending adapter is in use by some other leverage token
    /// @param adapter Adapter to check
    /// @return isUsed True if adapter is used by some leverage token
    function getIsLendingAdapterUsed(address adapter) external view returns (bool isUsed);

    /// @notice Returns lending adapter for the leverage token
    /// @param token Leverage token to get lending adapter for
    /// @return adapter Lending adapter for the leverage token
    function getLeverageTokenLendingAdapter(ILeverageToken token) external view returns (ILendingAdapter adapter);

    /// @notice Returns collateral asset for the leverage token
    /// @param token Leverage token to get collateral asset for
    /// @return collateralAsset Collateral asset for the leverage token
    function getLeverageTokenCollateralAsset(ILeverageToken token) external view returns (IERC20 collateralAsset);

    /// @notice Returns debt asset for the leverage token
    /// @param token Leverage token to get debt asset for
    /// @return debtAsset Debt asset for the leverage token
    function getLeverageTokenDebtAsset(ILeverageToken token) external view returns (IERC20 debtAsset);

    /// @notice Returns the rebalance module for the leverage token
    /// @param token Leverage token to get the rebalance module for
    /// @return module Rebalance module for the leverage token
    function getLeverageTokenRebalanceModule(ILeverageToken token) external view returns (IRebalanceAdapter module);

    /// @notice Returns target ratio for a leverage token
    /// @param token Leverage token to get target ratio for
    /// @return targetRatio Target ratio
    function getLeverageTokenTargetCollateralRatio(ILeverageToken token) external view returns (uint256 targetRatio);

    /// @notice Returns entire configuration for given leverage token
    /// @param token Leverage token to get config for
    /// @return config Leverage token configuration
    function getLeverageTokenConfig(ILeverageToken token) external view returns (LeverageTokenConfig memory config);

    /// @notice Returns all data required to describe current leverage token state - collateral, debt, equity and collateral ratio
    /// @param token Leverage token to query state for
    /// @return state Leverage token state
    function getLeverageTokenState(ILeverageToken token) external view returns (LeverageTokenState memory state);

    /// @notice Sets factory for creating new leverage tokens
    /// @param factory Factory to set
    /// @dev Only DEFAULT_ADMIN_ROLE can call this function
    function setLeverageTokenFactory(address factory) external;

    /// @notice Creates new leverage token with given config
    /// @param config Configuration of the leverage token
    /// @param name Name of the leverage token
    /// @param symbol Symbol of the leverage token
    /// @param rebalanceAdapterInitData Initialization data for the rebalance adapter
    /// @return token Address of the new leverage token
    function createNewLeverageToken(
        LeverageTokenConfig memory config,
        string memory name,
        string memory symbol,
        bytes memory rebalanceAdapterInitData
    ) external returns (ILeverageToken token);

    /// @notice Previews deposit function call and returns all required data
    /// @param token Leverage token to preview deposit for
    /// @param equityInCollateralAsset Equity to deposit denominated in collateral asset
    /// @return previewData Preview data for deposit
    ///         - collateralToAdd Amount of collateral that sender needs to approve the LeverageManager to spend,
    ///           this includes any fees
    ///         - debtToBorrow Amount of debt that will be borrowed and sent to sender
    ///         - equityInCollateralAsset Amount of equity that will be deposited before fees
    ///         - shares Amount of shares that will be minted to the sender
    ///         - tokenFee Amount of collateral asset that will be charged for the deposit to the leverage token
    ///         - treasuryFee Amount of collateral asset that will be charged for the deposit to the treasury
    /// @dev Sender should approve leverage manager to spend collateralToAdd amount of collateral asset
    function previewDeposit(ILeverageToken token, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory previewData);

    /// @notice Previews withdraw function call and returns all required data
    /// @param token Leverage token to preview withdraw for
    /// @param equityInCollateralAsset Equity to withdraw denominated in collateral asset
    /// @return previewData Preview data for withdraw
    ///         - collateralToRemove Amount of collateral that will be removed from the leverage token and sent to the sender
    ///         - debtToRepay Amount of debt that will be taken from sender and repaid to the leverage token
    ///         - equityInCollateralAsset Amount of equity that will be withdrawn before fees
    ///         - shares Amount of shares that will be burned from sender
    ///         - tokenFee Amount of collateral asset that will be charged for the withdraw to the leverage token
    ///         - treasuryFee Amount of collateral asset that will be charged for the withdraw to the treasury
    /// @dev Sender should approve leverage manager to spend debtToRepay amount of debt asset
    function previewWithdraw(ILeverageToken token, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory previewData);

    /// @notice Deposits equity into a leverage token and mints shares to the sender
    /// @param token The leverage token to deposit into
    /// @param equityInCollateralAsset The amount of equity to deposit denominated in the collateral asset of the leverage token
    /// @param minShares The minimum amount of shares to mint
    /// @return actionData Data about the deposit
    ///         - collateral Amount of collateral that was added, including any fees
    ///         - debt Amount of debt that was added
    ///         - equityInCollateralAsset Amount of equity that was deposited before fees
    ///         - shares Amount of shares minted to the sender
    ///         - tokenFee Amount of collateral that was charged for the deposit to the leverage token
    ///         - treasuryFee Amount of collateral that was charged for the deposit to the treasury
    function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (ActionData memory actionData);

    /// @notice Withdraws equity from a leverage token and burns shares from sender
    /// @param token The leverage token to withdraw from
    /// @param equityInCollateralAsset The amount of equity to withdraw denominated in the collateral asset of the leverage token
    /// @param maxShares The maximum amount of shares to burn
    /// @return actionData Data about the withdraw
    ///         - collateral Amount of collateral that was removed from leverage token and sent to sender
    ///         - debt Amount of debt that was repaid to leverage token, taken from sender
    ///         - equityInCollateralAsset Amount of equity that was withdrawn before fees
    ///         - shares Amount of the sender's shares that were burned for the withdrawal
    ///         - tokenFee Amount of collateral that was charged for the withdraw to the leverage token
    ///         - treasuryFee Amount of collateral that was charged for the withdraw to the treasury
    function withdraw(ILeverageToken token, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (ActionData memory actionData);

    /// @notice Rebalances leverage tokens based on provided actions
    /// @param actions Array of rebalance actions to execute (add collateral, remove collateral, borrow or repay)
    /// @param tokensIn Array of tokens to transfer in. Transfer from caller to leverage manager contract
    /// @param tokensOut Array of tokens to transfer out. Transfer from leverage manager contract to caller
    /// @dev Anyone can call this function. At the end function will just check if all effected leverage tokens are in the
    ///      better state than before rebalance. Caller needs to calculate and to provide tokens for rebalancing and he needs
    ///      to specify tokens that he wants to receive
    function rebalance(
        RebalanceAction[] calldata actions,
        TokenTransfer[] calldata tokensIn,
        TokenTransfer[] calldata tokensOut
    ) external;
}
