// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILendingAdapter} from "./ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "../storage/LeverageManagerStorage.sol";

interface ILeverageManager {
    /// @notice Error thrown when someone tries to set core of the strategy that is already set
    error CoreAlreadySet();

    /// @notice Error thrown when someone tries to set core that is invalid (contains zero addresses)
    error InvalidStrategyCore();

    /// @notice Error thrown when collateral ratios are invalid
    error InvalidCollateralRatios();

    /// @notice Error thrown when user wants to deposit more assets than he has or when tries to burn more shares than he has
    error InsufficientBalance();

    /// @notice Error thrown when user receives less shares than requested
    error InsufficientShares();

    /// @notice Error thrown when user receives less collateral assets than requested
    error InsufficientAssets();

    /// @notice Event emitted when core config of the strategy is set
    event StrategyCoreSet(address indexed strategy, Storage.StrategyCore core);

    /// @notice Event emitted when lending adapter is set for the strategy
    event StrategyLendingAdapterSet(address indexed strategy, address adapter);

    /// @notice Event emitted when collateral ratios are set for a strategy
    event StrategyCollateralRatiosSet(address indexed strategy, Storage.CollateralRatios ratios);

    /// @notice Event emitted when caps are set/changed for a strategy
    event StrategyCapSet(address indexed strategy, uint256 cap);

    /// @notice Event emitted when shares are minted to the user
    event Mint(address indexed strategy, address recipient, uint256 sharers);

    /// @notice Event emitted when user deposits assets into strategy
    event Deposit(
        address indexed strategy, address indexed from, address indexed to, uint256 assets, uint256 sharesMinted
    );

    /// @notice Event emitted when user redeems shares
    event Redeem(
        address indexed strategy, address indexed from, address indexed to, uint256 shares, uint256 collateral
    );

    /// @notice Returns core of the strategy which is collateral asset, debt asset and lending pool
    /// @param strategy Strategy to get assets for
    /// @return core Core config of the strategy
    function getStrategyCore(address strategy) external returns (Storage.StrategyCore memory core);

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
    function getStrategyCollateralRatios(address strategy) external returns (Storage.CollateralRatios memory ratios);

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

    /// @notice Returns the total collateral of the strategy denominated in collateral asset
    /// @param strategy The strategy to query collateral for
    /// @return collateral The total collateral of the strategy
    function getStrategyCollateral(address strategy) external view returns (uint256 collateral);

    /// @notice Returns total strategy debt denominated in debt asset
    /// @param strategy The strategy to query collateral for
    /// @return debt The total debt of the strategy
    function getStrategyDebt(address strategy) external view returns (uint256 debt);

    /// @notice Returns total equity of the strategy denominated in collateral asset
    /// @param strategy Strategy to query equity for
    /// @return equity Equity of the strategy
    function getStrategyEquity(address strategy) external view returns (uint256 equity);

    /// @notice Returns total equity of the strategy denominated in USD
    /// @param strategy Strategy to query equity for
    /// @return equityUSD Equity of the strategy
    function getStrategyEquityUSD(address strategy) external view returns (uint256 equityUSD);

    /// @notice Returns the amount of shares a user has in a strategy
    /// @param strategy The strategy to query shares for
    /// @param user The user to query shares for
    /// @return shares The amount of shares the user has in the strategy
    function getUserStrategyShares(address strategy, address user) external view returns (uint256 shares);

    /// @notice Returns the amount of assets a user has in a strategy
    /// @param strategy The strategy to query assets for
    /// @param user The user to query assets for
    /// @return assets The amount of assets the user has in the strategy
    function getUserStrategyAssets(address strategy, address user) external view returns (uint256 assets);

    /// @notice Returns equity of the strategy denominated in debt asset of the strategy
    /// @param strategy Strategy to query equity for
    /// @return equity Equity of the strategy
    /// @dev Equity is calculated as collateral - debt
    function getStrategyEquityInDebtAsset(address strategy) external view returns (uint256 equity);

    /// @notice Pauses entire contract
    /// @dev Only address with role GUARDIAN can call this function
    /// @dev Must emit PAUSE event
    function pause() external;

    /// @notice Unpauses contract
    /// @dev Only address with role GUARDIAN can call this function
    /// @dev Must emit UNPAUSE event
    function unpause() external;

    /// @notice Pauses actions on specific strategy
    /// @param strategy Strategy to pause
    /// @dev Must emit PAUSE event
    /// @dev One specific strategy should be paused only in case that strategy has issues with oracle that can lead to exploit but does not effect other strategies
    /// @dev Only GUARDIAN role can call this function
    function pauseStrategy(address strategy) external;

    /// @notice Unpauses actions on specific strategy
    /// @param strategy Strategy to unpause
    /// @dev Must emit UNPAUSE event
    /// @dev Only GUARDIAN role can call this function
    function unpauseStrategy(address strategy) external;

    /// @notice Sets core of the strategy which is collateral asset and debt asset
    /// @param strategy Strategy to set core for
    /// @param core Core config to set
    /// @dev Only MANAGER role can call this function. Core can be set only once and can never be changed
    function setStrategyCore(address strategy, Storage.StrategyCore calldata core) external;

    /// @notice Sets lending adapter for the strategy
    /// @param strategy Strategy to set lending adapter for
    /// @param adapter Adapter to set
    /// @dev Only MANAGER role can call this function
    function setStrategyLendingAdapter(address strategy, address adapter) external;

    /// @notice Sets collateral ratios for a strategy including min/max for rebalance and target
    /// @param strategy Strategy to set collateral ratios for
    /// @param ratios Collateral ratios to set
    /// @dev Only MANAGER role can call this function
    function setStrategyCollateralRatios(address strategy, Storage.CollateralRatios calldata ratios) external;

    /// @notice Sets cap for strategy
    /// @param strategy Strategy to set cap for
    /// @param cap Cap for strategy
    /// @dev Cap for strategy is leveraged amount in collateral asset
    /// @dev Only address with MANAGER role can call this function
    function setStrategyCollateralCap(address strategy, uint256 cap) external;

    /// @notice Mints shares of a strategy and deposits assets into it, recipient receives shares and debt
    /// @param strategy The strategy to deposit into
    /// @param assets The leveraged amount of assets to deposit
    /// @param recipient The address to receive the shares and debt
    /// @param minShares The minimum amount of shares to receive
    /// @return shares Actual amount of shares given to the user
    /// @dev Must emit the Deposit event
    function deposit(address strategy, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares);

    /// @notice Redeems shares of a strategy and withdraws assets from it, recipient receives assets but repays the debt
    /// @param strategy The strategy to redeem from
    /// @param shares Amount of shares to burn
    /// @param recipient The address to receive the collateral asset
    /// @param minAssets The minimum amount of assets to receive
    /// @return assets Actual amount of assets given to the user
    /// @dev Must emit the Redeem event
    function redeem(address strategy, uint256 shares, address recipient, uint256 minAssets)
        external
        returns (uint256 assets);

    // TODO: interface for rebalance functions
}
