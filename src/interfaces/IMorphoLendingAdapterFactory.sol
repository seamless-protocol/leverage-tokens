// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";

interface IMorphoLendingAdapterFactory {
    /// @notice Emitted when a new MorphoLendingAdapter is deployed.
    event MorphoLendingAdapterDeployed(IMorphoLendingAdapter lendingAdapter);

    /// @notice Given the `sender` and `baseSalt` compute and return the address that MorphoLendingAdapter will be deployed to
    /// using the `IMorphoLendingAdapterFactory.deployAdapter` function.
    /// @param sender The address of the sender of the `IMorphoLendingAdapterFactory.deployAdapter` call.
    /// @param baseSalt The user-provided salt.
    /// @dev MorphoLendingAdapter addresses are uniquely determined by their salt because the deployer is always the factory,
    /// and the use of minimal proxies means they all have identical bytecode and therefore an identical bytecode hash.
    /// @dev The `baseSalt` is the user-provided salt, not the final salt after hashing with the deployer's address.
    function computeAddress(address sender, bytes32 baseSalt) external view returns (address);

    /// @notice Deploys a new MorphoLendingAdapter contract with the specified configuration.
    /// @param morphoMarketId The Morpho market ID
    /// @param baseSalt Used to compute the resulting address of the MorphoLendingAdapter.
    /// @dev MorphoLendingAdapters deployed by this factory are minimal proxies.
    function deployAdapter(Id morphoMarketId, bytes32 baseSalt)
        external
        returns (IMorphoLendingAdapter lendingAdapter);
}
