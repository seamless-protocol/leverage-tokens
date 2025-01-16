// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorphoBase} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetCollateral is MorphoLendingAdapterBaseTest {
    function test_getCollateral() public {
        // MorphoLib, used by MorphoLendingAdapter, calls Morpho.extSloads to get the position's collateral
        bytes32[] memory returnValue = new bytes32[](2);
        returnValue[0] = bytes32(uint256(5e6 << 128));
        vm.mockCall(address(morpho), abi.encodeWithSelector(IMorphoBase.extSloads.selector), abi.encode(returnValue));

        assertEq(lendingAdapter.getCollateral(), 5e6);
    }
}
