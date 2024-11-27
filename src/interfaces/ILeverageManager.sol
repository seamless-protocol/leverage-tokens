// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILeverageManager {
    //TODO: Complete this once config struct is known
    function getStrategyConfig() external;

    /// @notice Returns oracle that manager relies on
    /// @return oracle Address of oracle smart contract
    /// @dev Oracle returns price for all assets in USD and has adapter for each asset
    function getOracle() external view returns (address oracle);

    /// @notice Returns strategy cap in collateral asset
    /// @param strategy Strategy to get cap for
    /// @return cap Strategy cap
    /// @dev Strategy cap is leveraged amount in collateral asset
    function getStrategyCap(uint256 strategy) external view returns (uint256 cap);

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

    /// @notice Sets cap for strategy
    /// @param strategy Strategy to set cap for
    /// @param cap Cap for strategy
    /// @dev Cap for strategy is leveraged amount in collateral asset
    /// @dev Only address with MANAGER role can call this function
    function setStrategyCap(address strategy, uint256 cap) external;

    // TODO: Change bytes to config struct one it is determined
    /// @notice Creates new strategy with provided configuration
    /// @param strategy Unique identifier for strategy
    /// @param collateralAsset Address of collateral asset
    /// @param debtAsset Address of debt asset
    /// @param config Strategy configuration
    /// @dev ADMIN role can change configuration after deployment but not collateral and debt assets
    /// @dev Reverts if strategy with given identifier already exists
    function createNewStrategy(address strategy, address collateralAsset, address debtAsset, bytes calldata config)
        external;

    /// @notice Mints shares of a strategy and deposits assets into it, recipient receives shares and debt
    /// @param strategy The strategy to deposit into
    /// @param assets The leveraged amount of assets to deposit
    /// @param recipient The address to receive the shares and debt
    /// @param minShares The minimum amount of shares to receive
    /// @dev Must emit the Deposit event
    function deposit(address strategy, uint256 assets, uint256 recipient, uint256 minShares) external;

    /// @notice Mints shares of a strategy and deposits assets into it, recipient receives shares and debt
    /// @param strategy The strategy to deposit into
    /// @param shares The exact amount of shares to mint
    /// @param recipient The address to receive the shares and debt
    /// @param maxAssets The maximum amount of assets to take from caller
    /// @dev Must emit the Deposit event
    function mint(address strategy, uint256 shares, uint256 recipient, uint256 maxAssets) external;

    /// @notice Burns shares of a strategy and withdraws assets from it, recipient receives assets and debt
    /// @param strategy The strategy to withdraw from
    /// @param assets The exact amount of assets to withdraw
    /// @param recipient The address to receive the assets and debt
    /// @param maxShares The minimum amount of assets to receive
    /// @dev Must emit the Withdraw event
    function withdraw(address strategy, uint256 assets, uint256 recipient, uint256 maxShares) external;

    /// @notice Burns shares of a strategy and withdraws assets from it, recipient receives assets and debt
    /// @param strategy The strategy to withdraw from
    /// @param shares The exact amount of shares to burn
    /// @param recipient The address to receive the assets and debt
    /// @param minAssets The minimum amount of assets to receive
    function burn(address strategy, uint256 shares, uint256 recipient, uint256 minAssets) external;
}
