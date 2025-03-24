// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IFeeManager} from "./IFeeManager.sol";
import {IStrategy} from "./IStrategy.sol";
import {IBeaconProxyFactory} from "./IBeaconProxyFactory.sol";
import {ILendingAdapter} from "./ILendingAdapter.sol";
import {ActionData, StrategyState, RebalanceAction, TokenTransfer, StrategyConfig} from "src/types/DataTypes.sol";
import {IRebalanceModule} from "./IRebalanceModule.sol";

interface ILeverageManager is IFeeManager {
    /// @notice Error thrown when someone tries to create strategy with lending adapter that already exists
    error LendingAdapterAlreadyInUse(address adapter);

    /// @notice Error thrown when someone tries to set zero address for collateral or debt asset when creating strategy
    error InvalidStrategyAssets();

    /// @notice Error thrown when collateral ratios are invalid
    error InvalidCollateralRatios();

    /// @notice Error thrown when slippage is too high during mint/redeem
    error SlippageTooHigh(uint256 actual, uint256 expected);

    /// @notice Error thrown when caller is whitelisted for rebalance action
    error NotRebalancer(IStrategy strategy, address caller);

    /// @notice Error thrown when strategy is not eligible for rebalance
    error StrategyNotEligibleForRebalance(IStrategy strategy);

    /// @notice Error thrown when strategy state after rebalance is invalid
    error InvalidStrategyStateAfterRebalance(IStrategy strategy);

    /// @notice Event emitted when strategy token factory is set
    event StrategyTokenFactorySet(address factory);

    /// @notice Event emitted when new strategy is created
    event StrategyCreated(IStrategy indexed strategy, IERC20 collateralAsset, IERC20 debtAsset, StrategyConfig config);

    /// @notice Event emitted when user deposits assets into strategy
    event Deposit(IStrategy indexed strategy, address indexed sender, ActionData actionData);

    /// @notice Event emitted when user withdraws assets from strategy
    event Withdraw(IStrategy indexed strategy, address indexed sender, ActionData actionData);

    /// @notice Returns factory for creating new strategy tokens
    /// @return factory Factory for creating new strategy tokens
    function getStrategyTokenFactory() external view returns (IBeaconProxyFactory factory);

    /// @notice Returns if lending adapter is in use by some other strategy
    /// @param adapter Adapter to check
    /// @return isUsed True if adapter is used by some strategy
    function getIsLendingAdapterUsed(address adapter) external view returns (bool isUsed);

    /// @notice Returns lending adapter for the strategy
    /// @param strategy Strategy to get lending adapter for
    /// @return adapter Lending adapter for the strategy
    function getStrategyLendingAdapter(IStrategy strategy) external view returns (ILendingAdapter adapter);

    /// @notice Returns collateral asset for the strategy
    /// @param strategy Strategy to get collateral asset for
    /// @return collateralAsset Collateral asset for the strategy
    function getStrategyCollateralAsset(IStrategy strategy) external view returns (IERC20 collateralAsset);

    /// @notice Returns debt asset for the strategy
    /// @param strategy Strategy to get debt asset for
    /// @return debtAsset Debt asset for the strategy
    function getStrategyDebtAsset(IStrategy strategy) external view returns (IERC20 debtAsset);

    /// @notice Returns the rebalance module for the strategy
    /// @param strategy Strategy to get the rebalance module for
    /// @return adapter Rebalance module for the strategy
    function getStrategyRebalanceModule(IStrategy strategy) external view returns (IRebalanceModule adapter);

    /// @notice Returns target ratio for a strategy
    /// @param strategy Strategy to get target ratio for
    /// @return targetRatio Target ratio
    function getStrategyTargetCollateralRatio(IStrategy strategy) external view returns (uint256 targetRatio);

    /// @notice Returns entire configuration for given strategy
    /// @param strategy Address of the strategy to get config for
    /// @return config Strategy configuration
    function getStrategyConfig(IStrategy strategy) external view returns (StrategyConfig memory config);

    /// @notice Returns all data required to describe current strategy state - collateral, debt, equity and collateral ratio
    /// @param strategy Strategy to query state for
    /// @return state Strategy state
    function getStrategyState(IStrategy strategy) external view returns (StrategyState memory state);

    /// @notice Sets factory for creating new strategy tokens
    /// @param factory Factory to set
    /// @dev Only DEFAULT_ADMIN_ROLE can call this function
    function setStrategyTokenFactory(address factory) external;

    /// @notice Creates new strategy with given config
    /// @param strategyConfig Configuration of the strategy
    /// @param name Name of the strategy token
    /// @param symbol Symbol of the strategy token
    /// @return strategy Address of the new strategy
    function createNewStrategy(StrategyConfig memory strategyConfig, string memory name, string memory symbol)
        external
        returns (IStrategy strategy);

    /// @notice Previews deposit function call and returns all required data
    /// @param strategy Strategy to preview deposit for
    /// @param equityInCollateralAsset Equity to deposit denominated in collateral asset
    /// @return previewData Preview data for deposit
    ///         - collateralToAdd Amount of collateral that sender needs to approve the LeverageManager to spend,
    ///           this includes any fees
    ///         - debtToBorrow Amount of debt that will be borrowed and sent to sender
    ///         - equityInCollateralAsset Amount of equity that will be deposited before fees
    ///         - shares Amount of shares that will be minted to the sender
    ///         - strategyFee Amount of collateral asset that will be charged for the deposit to the strategy
    ///         - treasuryFee Amount of collateral asset that will be charged for the deposit to the treasury
    /// @dev Sender should approve leverage manager to spend collateralToAdd amount of collateral asset
    function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory previewData);

    /// @notice Previews withdraw function call and returns all required data
    /// @param strategy Strategy to preview withdraw for
    /// @param equityInCollateralAsset Equity to withdraw denominated in collateral asset
    /// @return previewData Preview data for withdraw
    ///         - collateralToRemove Amount of collateral that will be removed from the strategy and sent to the sender
    ///         - debtToRepay Amount of debt that will be taken from sender and repaid to the strategy
    ///         - equityInCollateralAsset Amount of equity that will be withdrawn before fees
    ///         - shares Amount of shares that will be burned from sender
    ///         - strategyFee Amount of collateral asset that will be charged for the withdraw to the strategy
    ///         - treasuryFee Amount of collateral asset that will be charged for the withdraw to the treasury
    /// @dev Sender should approve leverage manager to spend debtToRepay amount of debt asset
    function previewWithdraw(IStrategy strategy, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory previewData);

    /// @notice Deposits equity into a strategy and mints shares to the sender
    /// @param strategy The strategy to deposit into
    /// @param equityInCollateralAsset The amount of equity to deposit denominated in the collateral asset of the strategy
    /// @param minShares The minimum amount of shares to mint
    /// @return actionData Data about the deposit
    ///         - collateral Amount of collateral that was added, including any fees
    ///         - debt Amount of debt that was added
    ///         - equityInCollateralAsset Amount of equity that was deposited before fees
    ///         - shares Amount of shares minted to the sender
    ///         - strategyFee Amount of collateral that was charged for the deposit to the strategy
    ///         - treasuryFee Amount of collateral that was charged for the deposit to the treasury
    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (ActionData memory actionData);

    /// @notice Withdraws equity from a strategy and burns shares from sender
    /// @param strategy The strategy to withdraw from
    /// @param equityInCollateralAsset The amount of equity to withdraw denominated in the collateral asset of the strategy
    /// @param maxShares The maximum amount of shares to burn
    /// @return actionData Data about the withdraw
    ///         - collateral Amount of collateral that was removed from strategy and sent to sender
    ///         - debt Amount of debt that was repaid to strategy, taken from sender
    ///         - equityInCollateralAsset Amount of equity that was withdrawn before fees
    ///         - shares Amount of the sender's shares that were burned for the withdrawal
    ///         - strategyFee Amount of collateral that was charged for the withdraw to the strategy
    ///         - treasuryFee Amount of collateral that was charged for the withdraw to the treasury
    function withdraw(IStrategy strategy, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (ActionData memory actionData);

    /// @notice Rebalances strategies based on provided actions
    /// @param actions Array of rebalance actions to execute (add collateral, remove collateral, borrow or repay)
    /// @param tokensIn Array of tokens to transfer in. Transfer from caller to leverage manager contract
    /// @param tokensOut Array of tokens to transfer out. Transfer from leverage manager contract to caller
    /// @dev Anyone can call this function. At the end function will just check if all effected strategies are in the
    ///      better state than before rebalance. Caller needs to calculate and to provide tokens for rebalancing and he needs
    ///      to specify tokens that he wants to receive
    function rebalance(
        RebalanceAction[] calldata actions,
        TokenTransfer[] calldata tokensIn,
        TokenTransfer[] calldata tokensOut
    ) external;
}
