// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {CollateralRatios} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "./ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "../storage/LeverageManagerStorage.sol";

interface ILeverageManager {
    /// @notice Error thrown when someone tries to set strategy that already exists
    error StrategyAlreadyExists(address strategy);

    /// @notice Error thrown when someone tries to set zero address for collateral or debt asset when creating strategy
    error InvalidStrategyAssets();

    /// @notice Error thrown when someone tries to set zero address as lending adapter for some strategy
    error InvalidLendingAdapter(address adapter);

    /// @notice Error thrown when collateral ratios are invalid
    error InvalidCollateralRatios();

    /// @notice Error thrown when user tries to deposit into strategy more than cap
    error CollateralExceedsCap(uint256 collateral, uint256 cap);

    /// @notice Error thrown when user receives less shares than requested
    error InsufficientShares(uint256 received, uint256 expected);

    /// @notice Error thrown when user receives less assets than requested
    error InsufficientAssets(uint256 received, uint256 expected);

    /// @notice Error thrown when user tries to burn more shares than they have
    error InsufficientBalance(uint256 requested, uint256 actual);

    /// @notice Event emitted when lending adapter is set for the strategy
    event StrategyLendingAdapterSet(address indexed strategy, address adapter);

    /// @notice Event emitted when new strategy is created
    event StrategyCreated(address indexed strategy, address indexed collateralAsset, address indexed debtAsset);

    /// @notice Event emitted when collateral ratios are set for a strategy
    event StrategyCollateralRatiosSet(address indexed strategy, CollateralRatios ratios);

    /// @notice Event emitted when collateral caps are set/changed for a strategy
    event StrategyCollateralCapSet(address indexed strategy, uint256 collateralCap);

    /// @notice Event emitted when shares are minted to the user
    event Mint(address indexed strategy, address recipient, uint256 sharers);

    /// @notice Event emitted when user deposits assets into strategy
    event Deposit(
        address indexed strategy, address indexed from, address indexed to, uint256 assets, uint256 sharesMinted
    );

    /// @notice Event emitted when user redeems assets from strategy
    event Redeem(address indexed strategy, address indexed from, uint256 shares, uint256 collateral, uint256 debt);

    /// @notice Returns lending adapter for the strategy
    /// @param strategy Strategy to get lending adapter for
    /// @return adapter Lending adapter for the strategy
    function getStrategyLendingAdapter(address strategy) external view returns (ILendingAdapter adapter);

    /// @notice Returns strategy cap in collateral asset
    /// @param strategy Strategy to get cap for
    /// @return cap Strategy cap
    /// @dev Strategy cap is leveraged amount in collateral asset
    function getStrategyCollateralCap(address strategy) external view returns (uint256 cap);

    /// @notice Returns leverage config for a strategy including min, max and target
    /// @param strategy Strategy to get leverage config for
    /// @return ratios Collateral ratios for the strategy
    function getStrategyCollateralRatios(address strategy) external returns (CollateralRatios memory ratios);

    /// @notice Returns target ratio for a strategy
    /// @param strategy Strategy to get target ratio for
    /// @return targetRatio Target ratio
    function getStrategyTargetCollateralRatio(address strategy) external view returns (uint256 targetRatio);

    /// @notice Returns collateral asset of the strategy
    /// @notice Collateral asset is the asset that is deposited into lending pool
    /// @param strategy Strategy to get collateral asset for
    /// @return collateral Collateral asset
    function getStrategyCollateralAsset(address strategy) external view returns (address collateral);

    /// @notice Returns debt asset of the strategy
    /// @notice Debt asset is the asset that is borrowed from lending pool
    /// @param strategy Strategy to get debt asset for
    /// @return debt Debt asset
    function getStrategyDebtAsset(address strategy) external view returns (address debt);

    /// @notice Returns entire configuration for given strategy
    /// @param strategy Address of the strategy to get config for
    /// @return config Strategy configuration
    function getStrategyConfig(address strategy) external returns (Storage.StrategyConfig memory config);

    /// @notice Returns the total amount of shares in circulation for a given strategy
    /// @param strategy The strategy to query shares for
    /// @return shares The total amount of shares in circulation for the strategy
    function getTotalStrategyShares(address strategy) external view returns (uint256 shares);

    /// @notice Returns the amount of shares a user has in a strategy
    /// @param strategy The strategy to query shares for
    /// @param user The user to query shares for
    /// @return shares The amount of shares the user has in the strategy
    function getUserStrategyShares(address strategy, address user) external view returns (uint256 shares);

    /// @notice Creates new strategy with given config
    /// @param strategy Address of the new strategy
    /// @param strategyConfig Configuration of the strategy
    /// @dev Only MANAGER role can execute this.
    ///      If collateralAsset,debtAsset or lendingAdapter are zero addresses function will revert
    function createNewStrategy(address strategy, Storage.StrategyConfig memory strategyConfig) external;

    /// @notice Sets lending adapter for the strategy
    /// @param strategy Strategy to set lending adapter for
    /// @param adapter Adapter to set
    /// @dev Only MANAGER role can call this function
    function setStrategyLendingAdapter(address strategy, address adapter) external;

    /// @notice Sets collateral ratios for a strategy including min/max for rebalance and target
    /// @param strategy Strategy to set collateral ratios for
    /// @param ratios Collateral ratios to set
    /// @dev Only MANAGER role can call this function
    ///      If collateral ratios are not valid function will revert
    function setStrategyCollateralRatios(address strategy, CollateralRatios calldata ratios) external;

    /// @notice Sets collateral cap for strategy
    /// @param strategy Strategy to set cap for
    /// @param collateralCap Cap for strategy
    /// @dev Cap for strategy is leveraged amount in collateral asset
    /// @dev Only address with MANAGER role can call this function
    function setStrategyCollateralCap(address strategy, uint256 collateralCap) external;

    /// @notice Mints shares of a strategy and deposits assets into it, recipient receives shares but caller receives debt
    /// @param strategy The strategy to deposit into
    /// @param assets The quantity of assets to deposit
    /// @param recipient The address to receive the shares and debt
    /// @param minShares The minimum amount of shares to receive
    /// @return shares Actual amount of shares given to the user
    /// @dev Must emit the Deposit event
    function deposit(address strategy, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares);

    /// @notice Redeems shares of a strategy and withdraws assets from it, sender receives assets and caller pays debt
    /// @param strategy The strategy to redeem from
    /// @param shares The quantity of shares to redeem
    /// @param minAssets The minimum amount of collateral to receive
    /// @return assets Actual amount of assets given to the user
    function redeem(address strategy, uint256 shares, uint256 minAssets) external returns (uint256 assets);
}
