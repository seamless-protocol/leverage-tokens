// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IPreLiquidationLendingAdapter} from "./IPreLiquidationLendingAdapter.sol";
import {ILeverageManager} from "./ILeverageManager.sol";

// Aave v3 imports
import {IPool} from "@aave-v3-origin/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol";

/// @title IAaveLendingAdapter
/// @notice Interface for the Aave v3 Lending Adapter
/// @dev IMPORTANT: This adapter deliberately does NOT use Aave's aggregated position functions like
/// `getUserAccountData()` to determine position state. Instead, it tracks collateral and debt using
/// the specific aToken and variableDebtToken balances for the configured assets only.
///
/// This design protects against manipulation via "foreign collateral donations" - where someone
/// supplies a different asset on behalf of this adapter in Aave. Such donations would affect
/// Aave's aggregated position calculations but do NOT affect this adapter's view of its position.
///
/// Foreign collateral can be rescued using the `rescueForeignCollateral()` function.
interface IAaveLendingAdapter is IPreLiquidationLendingAdapter {
    /// @notice Event emitted when the AaveLendingAdapter is initialized
    /// @param collateralAsset The address of the collateral asset
    /// @param debtAsset The address of the debt asset
    /// @param authorizedCreator The authorized creator of the AaveLendingAdapter
    event AaveLendingAdapterInitialized(
        address indexed collateralAsset, address indexed debtAsset, address indexed authorizedCreator
    );

    /// @notice Event emitted when the AaveLendingAdapter is flagged as used
    event AaveLendingAdapterUsed();

    /// @notice Event emitted when the eMode is updated
    /// @param previousEModeCategory The previous eMode category id
    /// @param newEModeCategory The new eMode category id
    event EModeUpdated(uint8 previousEModeCategory, uint8 newEModeCategory);

    /// @notice Event emitted when foreign collateral is rescued from the adapter
    /// @param asset The address of the rescued asset
    /// @param recipient The address that received the rescued assets
    /// @param amount The amount of assets rescued
    event ForeignCollateralRescued(address indexed asset, address indexed recipient, uint256 amount);

    /// @notice Thrown when someone tries to create a LeverageToken with this AaveLendingAdapter but it is already in use
    error LendingAdapterAlreadyInUse();

    /// @notice Thrown when trying to rescue the configured collateral asset (use removeCollateral instead)
    error CannotRescueCollateralAsset();

    /// @notice The authorized creator of the AaveLendingAdapter
    /// @return _authorizedCreator The authorized creator of the AaveLendingAdapter
    /// @dev Only the authorized creator can create a new LeverageToken using this adapter on the LeverageManager
    function authorizedCreator() external view returns (address _authorizedCreator);

    /// @notice Whether the AaveLendingAdapter is in use
    /// @return _isUsed Whether the AaveLendingAdapter is in use
    /// @dev If this is true, the AaveLendingAdapter cannot be used to create a new LeverageToken
    function isUsed() external view returns (bool _isUsed);

    /// @notice The LeverageManager contract
    /// @return _leverageManager The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Aave v3 Pool contract
    /// @return _pool The Aave v3 Pool contract
    function pool() external view returns (IPool _pool);

    /// @notice The Aave v3 PoolAddressesProvider contract
    /// @return _addressesProvider The Aave v3 PoolAddressesProvider contract
    function addressesProvider() external view returns (IPoolAddressesProvider _addressesProvider);

    /// @notice The collateral asset address
    /// @return _collateralAsset The collateral asset address
    function collateralAsset() external view returns (address _collateralAsset);

    /// @notice The debt asset address
    /// @return _debtAsset The debt asset address
    function debtAsset() external view returns (address _debtAsset);

    /// @notice The current eMode category id from the Aave pool
    /// @return _eModeCategory The eMode category id (0 = no eMode)
    function eModeCategory() external view returns (uint8 _eModeCategory);

    /// @notice The aToken address for the collateral asset
    /// @return _aToken The aToken address
    function aToken() external view returns (IERC20 _aToken);

    /// @notice The variable debt token address for the debt asset
    /// @return _variableDebtToken The variable debt token address
    function variableDebtToken() external view returns (IERC20 _variableDebtToken);

    /// @notice The decimals of the collateral asset
    /// @return _collateralDecimals The decimals of the collateral asset
    function collateralDecimals() external view returns (uint8 _collateralDecimals);

    /// @notice The decimals of the debt asset
    /// @return _debtDecimals The decimals of the debt asset
    function debtDecimals() external view returns (uint8 _debtDecimals);

    /// @notice Error thrown when trying to set an invalid eMode
    /// @param newEModeCategory The invalid eMode category that was attempted
    error InvalidEMode(uint8 newEModeCategory);

    /// @notice Sets a new eMode for the lending adapter
    /// @dev Only allows setting an eMode that is valid and better than (or equal to) the current eMode.
    ///      This is permissionless since it only benefits the leverage token holders.
    /// @param newEModeCategory The eMode category to set (0 to disable eMode)
    function setEMode(uint8 newEModeCategory) external;

    /// @notice Validates that a new eMode category is valid and better than (or equal to) the current eMode
    /// @dev Checks that:
    ///      1. The collateral asset is valid collateral in the new eMode
    ///      2. The debt asset is borrowable in the new eMode
    ///      3. The collateral has non-zero LTV in the new eMode
    ///      4. The new eMode's LTV is >= current eMode's LTV
    /// @param newEModeCategory The eMode category to validate (0 to disable eMode)
    /// @return isValid True if the new eMode is valid and beneficial
    function validateEMode(uint8 newEModeCategory) external view returns (bool isValid);

    /// @notice Rescues foreign collateral that was supplied to this adapter in Aave
    /// @dev In Aave, anyone can supply assets on behalf of any address. If someone supplies
    ///      an asset other than the configured collateral asset, those assets become "trapped"
    ///      since this adapter only manages the configured collateral asset.
    ///
    ///      This function allows rescuing such foreign collateral by withdrawing it from Aave
    ///      and sending it to a specified recipient.
    ///
    ///      IMPORTANT: This function cannot be used to rescue the configured collateral asset.
    ///      Use the normal `removeCollateral()` function for that.
    ///
    /// @param asset The address of the foreign asset to rescue
    /// @param recipient The address to receive the rescued assets
    /// @return amount The amount of assets rescued
    function rescueForeignCollateral(address asset, address recipient) external returns (uint256 amount);
}
