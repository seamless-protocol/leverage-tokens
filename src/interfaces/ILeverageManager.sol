// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IStrategy} from "./IStrategy.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";
import {IBeaconProxyFactory} from "./IBeaconProxyFactory.sol";
import {ILendingAdapter} from "./ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "../storage/LeverageManagerStorage.sol";

interface ILeverageManager {
    /// @notice Error thrown when someone tries to create strategy with lending adapter that already exists
    error LendingAdapterAlreadyInUse(address adapter);

    /// @notice Error thrown when someone tries to set zero address for collateral or debt asset when creating strategy
    error InvalidStrategyAssets();

    /// @notice Error thrown when collateral ratios are invalid
    error InvalidCollateralRatios();

    /// @notice Error thrown when manager tries to set invalid reward percentage
    error InvalidRewardPercentage(uint256 reward);

    /// @notice Error thrown when user tries to deposit into strategy more than cap
    error CollateralExceedsCap(uint256 collateral, uint256 cap);

    /// @notice Error thrown when slippage is too high during mint/redeem
    error SlippageTooHigh(uint256 actual, uint256 expected);

    /// @notice Error thrown when strategy is not eligible for rebalance
    error StrategyNotEligibleForRebalance(IStrategy strategy);

    /// @notice Error thrown when collateral ratio after rebalance is worse than before rebalance
    error CollateralRatioInvalid();

    /// @notice Error thrown when collateral ratio after rebalance is on the opposite side of target ratio than before rebalance
    error TooBigCollateralRatioChange();

    /// @notice Error thrown when equity loss on rebalance is too big
    error EquityLossTooBig();

    /// @notice Event emitted when strategy token factory is set
    event StrategyTokenFactorySet(address factory);

    /// @notice Event emitted when lending adapter is set for the strategy
    event StrategyLendingAdapterSet(IStrategy indexed strategy, address adapter);

    /// @notice Event emitted when new strategy is created
    event StrategyCreated(
        IStrategy indexed strategy, IERC20 collateralAsset, IERC20 debtAsset, Storage.StrategyConfig config
    );

    /// @notice Event emitted when collateral ratios are set for a strategy
    event StrategyCollateralRatiosSet(IStrategy indexed strategy, CollateralRatios ratios);

    /// @notice Event emitted when collateral caps are set/changed for a strategy
    event StrategyCollateralCapSet(IStrategy indexed strategy, uint256 collateralCap);

    /// @notice Event emitted when rebalance reward is set for a strategy
    event StrategyRebalanceRewardSet(IStrategy indexed strategy, uint256 reward);

    /// @notice Event emitted when user deposits assets into strategy
    event Deposit(
        IStrategy indexed strategy, address indexed from, address indexed to, uint256 assets, uint256 sharesMinted
    );

    /// @notice Event emitted when user redeems assets from strategy
    event Redeem(IStrategy indexed strategy, address indexed from, uint256 shares, uint256 collateral, uint256 debt);

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

    /// @notice Returns reward for rebalancing strategy
    /// @param strategy Strategy to get reward for
    /// @return reward Reward for rebalancing strategy, percentage of debt change where 100_00 = 100%
    function getStrategyRebalanceReward(IStrategy strategy) external view returns (uint256 reward);

    /// @notice Returns strategy cap in collateral asset
    /// @param strategy Strategy to get cap for
    /// @return cap Strategy cap
    /// @dev Strategy cap is leveraged amount in collateral asset
    function getStrategyCollateralCap(IStrategy strategy) external view returns (uint256 cap);

    /// @notice Returns leverage config for a strategy including min, max and target
    /// @param strategy Strategy to get leverage config for
    /// @return ratios Collateral ratios for the strategy
    function getStrategyCollateralRatios(IStrategy strategy) external returns (CollateralRatios memory ratios);

    /// @notice Returns target ratio for a strategy
    /// @param strategy Strategy to get target ratio for
    /// @return targetRatio Target ratio
    function getStrategyTargetCollateralRatio(IStrategy strategy) external view returns (uint256 targetRatio);

    /// @notice Returns entire configuration for given strategy
    /// @param strategy Address of the strategy to get config for
    /// @return config Strategy configuration
    function getStrategyConfig(IStrategy strategy) external returns (Storage.StrategyConfig memory config);

    /// @notice Sets factory for creating new strategy tokens
    /// @param factory Factory to set
    /// @dev Only DEFAULT_ADMIN_ROLE can call this function
    function setStrategyTokenFactory(address factory) external;

    /// @notice Creates new strategy with given config
    /// @param strategyConfig Configuration of the strategy
    /// @param name Name of the strategy token
    /// @param symbol Symbol of the strategy token
    /// @return strategy Address of the new strategy
    /// @dev Only MANAGER role can execute this.
    ///      If collateralAsset,debtAsset or lendingAdapter are zero addresses function will revert
    function createNewStrategy(Storage.StrategyConfig memory strategyConfig, string memory name, string memory symbol)
        external
        returns (IStrategy strategy);

    /// @notice Sets lending adapter for the strategy
    /// @param strategy Strategy to set lending adapter for
    /// @param adapter Adapter to set
    /// @dev Only MANAGER role can call this function
    function setStrategyLendingAdapter(IStrategy strategy, address adapter) external;

    /// @notice Sets collateral ratios for a strategy including min/max for rebalance and target
    /// @param strategy Strategy to set collateral ratios for
    /// @param ratios Collateral ratios to set
    /// @dev Only MANAGER role can call this function
    ///      If collateral ratios are not valid function will revert
    function setStrategyCollateralRatios(IStrategy strategy, CollateralRatios calldata ratios) external;

    /// @notice Sets collateral cap for strategy
    /// @param strategy Strategy to set cap for
    /// @param collateralCap Cap for strategy
    /// @dev Cap for strategy is leveraged amount in collateral asset
    /// @dev Only address with MANAGER role can call this function
    function setStrategyCollateralCap(IStrategy strategy, uint256 collateralCap) external;

    /// @notice Sets reward for rebalancing strategy
    /// @param strategy Strategy to set reward for
    /// @param reward Reward for rebalancing strategy, percentage of debt change where 100_00 = 100%
    /// @dev Only address with MANAGER role can call this function
    function setStrategyRebalanceReward(IStrategy strategy, uint256 reward) external;

    /// @notice Mints shares of a strategy and deposits assets into it, recipient receives shares but caller receives debt
    /// @param strategy The strategy to deposit into
    /// @param shares The quantity of shares to mint
    /// @param maxAssets The maximum amount of equity to take from the user denominated in debt asset
    /// @return assets Actual amount of equity taken from the user denominated in debt asset
    function mint(IStrategy strategy, uint256 shares, uint256 maxAssets) external returns (uint256 assets);

    /// @notice Redeems shares of a strategy and withdraws assets from it, sender receives assets and caller pays debt
    /// @param strategy The strategy to redeem from
    /// @param shares The quantity of shares to redeem
    /// @param minAssets The minimum amount of collateral to receive
    /// @return assets Actual amount of assets given to the user
    function redeem(IStrategy strategy, uint256 shares, uint256 minAssets) external returns (uint256 assets);
}
