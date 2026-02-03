// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IAaveLendingAdapter} from "src/interfaces/IAaveLendingAdapter.sol";

interface IAaveLendingAdapterFactory {
    /// @notice Emitted when a new AaveLendingAdapter is deployed.
    /// @param lendingAdapter The deployed AaveLendingAdapter
    event AaveLendingAdapterDeployed(IAaveLendingAdapter lendingAdapter);

    /// @notice Given the `sender` and `baseSalt` compute and return the address that AaveLendingAdapter will be deployed to
    /// using the `IAaveLendingAdapterFactory.deployAdapter` function.
    /// @param sender The address of the sender of the `IAaveLendingAdapterFactory.deployAdapter` call.
    /// @param baseSalt The user-provided salt.
    /// @dev AaveLendingAdapter addresses are uniquely determined by their salt because the deployer is always the factory,
    /// and the use of minimal proxies means they all have identical bytecode and therefore an identical bytecode hash.
    /// @dev The `baseSalt` is the user-provided salt, not the final salt after hashing with the sender's address.
    function computeAddress(address sender, bytes32 baseSalt) external view returns (address);

    /// @notice Returns the address of the AaveLendingAdapter logic contract used to deploy minimal proxies.
    function lendingAdapterLogic() external view returns (IAaveLendingAdapter);

    /// @notice Deploys a new AaveLendingAdapter contract with the specified configuration.
    /// @param collateralAsset The address of the collateral asset
    /// @param debtAsset The address of the debt asset
    /// @param authorizedCreator The authorized creator of the deployed AaveLendingAdapter. The authorized creator can create a
    /// new LeverageToken using this adapter on the LeverageManager
    /// @param baseSalt Used to compute the resulting address of the AaveLendingAdapter.
    /// @dev AaveLendingAdapters deployed by this factory are minimal proxies.
    /// @dev The optimal eMode is automatically set during initialization.
    function deployAdapter(
        address collateralAsset,
        address debtAsset,
        address authorizedCreator,
        bytes32 baseSalt
    ) external returns (IAaveLendingAdapter lendingAdapter);
}
