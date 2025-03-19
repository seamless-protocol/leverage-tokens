// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {MorphoLendingAdapterFactoryBase} from "./MorphoLendingAdapterFactoryBase.t.sol";

contract MorphoLendingAdapterFactoryComputeAddressTest is MorphoLendingAdapterFactoryBase {
    /// forge-config: default.fuzz.runs = 1
    function test_computeAddress_SameSaltDifferentSender(address senderA, address senderB, bytes32 baseSalt)
        public
        view
    {
        vm.assume(senderA != senderB);

        address computedAddressA = factory.computeAddress(senderA, baseSalt);
        address computedAddressB = factory.computeAddress(senderB, baseSalt);
        assertNotEq(computedAddressA, computedAddressB);
    }

    /// forge-config: default.fuzz.runs = 1
    function test_computeAddress_SameSenderDifferentSalt(address sender, bytes32 baseSaltA, bytes32 baseSaltB)
        public
        view
    {
        vm.assume(baseSaltA != baseSaltB);

        address computedAddressA = factory.computeAddress(sender, baseSaltA);
        address computedAddressB = factory.computeAddress(sender, baseSaltB);
        assertNotEq(computedAddressA, computedAddressB);
    }
}
