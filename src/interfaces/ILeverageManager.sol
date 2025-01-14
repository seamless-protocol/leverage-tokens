// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {CollateralRatios} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "./ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

interface ILeverageManager {
    /// @notice Error thrown when someone tries to set strategy that already exists
    error StrategyAlreadyExists(uint256 strategyId);

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

    /// @notice Event emitted when lending adapter is set for the strategy
    event StrategyLendingAdapterSet(uint256 indexed strategyId, address adapter);

    /// @notice Event emitted when new strategy is created
    event StrategyCreated(uint256 indexed strategyId, address indexed collateralAsset, address indexed debtAsset);

    /// @notice Event emitted when collateral ratios are set for a strategy
    event StrategyCollateralRatiosSet(uint256 indexed strategyId, CollateralRatios ratios);

    /// @notice Event emitted when collateral caps are set/changed for a strategy
    event StrategyCollateralCapSet(uint256 indexed strategyId, uint256 collateralCap);

    /// @notice Event emitted when shares are minted to the user
    event Mint(uint256 indexed strategyId, address recipient, uint256 sharers);

    /// @notice Event emitted when user deposits assets into strategy
    event Deposit(
        uint256 indexed strategyId, address indexed from, address indexed to, uint256 assets, uint256 sharesMinted
    );

    /// @notice Returns lending adapter for the strategy
    /// @param strategyId Strategy to get lending adapter for
    /// @return adapter Lending adapter for the strategy
    function getStrategyLendingAdapter(uint256 strategyId) external view returns (ILendingAdapter adapter);

    /// @notice Returns strategy cap in collateral asset
    /// @param strategyId Strategy to get cap for
    /// @return cap Strategy cap
    /// @dev Strategy cap is leveraged amount in collateral asset
    function getStrategyCollateralCap(uint256 strategyId) external view returns (uint256 cap);

    /// @notice Returns leverage config for a strategy including min, max and target
    /// @param strategyId Strategy to get leverage config for
    /// @return ratios Collateral ratios for the strategy
    function getStrategyCollateralRatios(uint256 strategyId) external returns (CollateralRatios memory ratios);

    /// @notice Returns target ratio for a strategy
    /// @param strategyId Strategy to get target ratio for
    /// @return targetRatio Target ratio
    function getStrategyTargetCollateralRatio(uint256 strategyId) external view returns (uint256 targetRatio);

    /// @notice Returns collateral asset of the strategy
    /// @notice Collateral asset is the asset that is deposited into lending pool
    /// @param strategyId Strategy to get collateral asset for
    /// @return collateral Collateral asset
    function getStrategyCollateralAsset(uint256 strategyId) external view returns (address collateral);

    /// @notice Returns debt asset of the strategy
    /// @notice Debt asset is the asset that is borrowed from lending pool
    /// @param strategyId Strategy to get debt asset for
    /// @return debt Debt asset
    function getStrategyDebtAsset(uint256 strategyId) external view returns (address debt);

    /// @notice Returns entire configuration for given strategy
    /// @param strategyId Strategy to get config for
    /// @return config Strategy configuration
    function getStrategyConfig(uint256 strategyId) external returns (Storage.StrategyConfig memory config);

    /// @notice Returns the total amount of shares in circulation for a given strategy
    /// @param strategyId The strategy to query shares for
    /// @return shares The total amount of shares in circulation for the strategy
    function getTotalStrategyShares(uint256 strategyId) external view returns (uint256 shares);

    /// @notice Returns the amount of shares a user has in a strategy
    /// @param strategyId The strategy to query shares for
    /// @param user The user to query shares for
    /// @return shares The amount of shares the user has in the strategy
    function getUserStrategyShares(uint256 strategyId, address user) external view returns (uint256 shares);

    /// @notice Creates new strategy with given config
    /// @param strategyId Id of the new strategy
    /// @param strategyConfig Configuration of the strategy
    /// @dev Only MANAGER role can execute this.
    ///      If collateralAsset,debtAsset or lendingAdapter are zero addresses function will revert
    function createNewStrategy(uint256 strategyId, Storage.StrategyConfig memory strategyConfig) external;

    /// @notice Sets lending adapter for the strategy
    /// @param strategyId Strategy to set lending adapter for
    /// @param adapter Adapter to set
    /// @dev Only MANAGER role can call this function
    function setStrategyLendingAdapter(uint256 strategyId, address adapter) external;

    /// @notice Sets collateral ratios for a strategy including min/max for rebalance and target
    /// @param strategyId Strategy to set collateral ratios for
    /// @param ratios Collateral ratios to set
    /// @dev Only MANAGER role can call this function
    ///      If collateral ratios are not valid function will revert
    function setStrategyCollateralRatios(uint256 strategyId, CollateralRatios calldata ratios) external;

    /// @notice Sets collateral cap for strategy
    /// @param strategyId Strategy to set cap for
    /// @param collateralCap Cap for strategy
    /// @dev Cap for strategy is leveraged amount in collateral asset
    /// @dev Only address with MANAGER role can call this function
    function setStrategyCollateralCap(uint256 strategyId, uint256 collateralCap) external;

    /// @notice Mints shares of a strategy and deposits assets into it, recipient receives shares but caller receives debt
    /// @param strategyId The strategy to deposit into
    /// @param assets The quantity of assets to deposit
    /// @param recipient The address to receive the shares and debt
    /// @param minShares The minimum amount of shares to receive
    /// @return shares Actual amount of shares given to the user
    /// @dev Must emit the Deposit event
    function deposit(uint256 strategyId, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares);

    // TODO: interface for rebalance functions
}
