// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";

// Internal imports
import {IAaveLendingAdapter} from "src/interfaces/IAaveLendingAdapter.sol";
import {IAaveLendingAdapterFactory} from "src/interfaces/IAaveLendingAdapterFactory.sol";
import {AaveLendingAdapter} from "src/lending/AaveLendingAdapter.sol";

/**
 * @dev The AaveLendingAdapterFactory is a factory contract for deploying ERC-1167 minimal proxies of the
 * AaveLendingAdapter contract using OpenZeppelin's Clones library.
 *
 * @custom:contact security@seamlessprotocol.com
 */
contract AaveLendingAdapterFactory is IAaveLendingAdapterFactory {
    using Clones for address;

    /// @inheritdoc IAaveLendingAdapterFactory
    IAaveLendingAdapter public immutable lendingAdapterLogic;

    /// @param _lendingAdapterLogic Logic contract for deploying new AaveLendingAdapters.
    constructor(IAaveLendingAdapter _lendingAdapterLogic) {
        lendingAdapterLogic = _lendingAdapterLogic;
    }

    /// @inheritdoc IAaveLendingAdapterFactory
    function computeAddress(address sender, bytes32 baseSalt) external view returns (address) {
        return Clones.predictDeterministicAddress(address(lendingAdapterLogic), salt(sender, baseSalt), address(this));
    }

    /// @inheritdoc IAaveLendingAdapterFactory
    function deployAdapter(
        address collateralAsset,
        address debtAsset,
        address authorizedCreator,
        bytes32 baseSalt
    ) public returns (IAaveLendingAdapter) {
        IAaveLendingAdapter lendingAdapter =
            IAaveLendingAdapter(address(lendingAdapterLogic).cloneDeterministic(salt(msg.sender, baseSalt)));
        emit AaveLendingAdapterDeployed(lendingAdapter);

        AaveLendingAdapter(address(lendingAdapter)).initialize(
            collateralAsset, debtAsset, authorizedCreator
        );

        return lendingAdapter;
    }

    /// @notice Given the `sender` and `baseSalt`, return the salt that will be used for deployment.
    /// @param sender The address of the sender of the `deployAdapter` call.
    /// @param baseSalt The user-provided base salt.
    function salt(address sender, bytes32 baseSalt) internal pure returns (bytes32) {
        return keccak256(abi.encode(sender, baseSalt));
    }
}
