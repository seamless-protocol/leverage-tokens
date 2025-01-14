// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";

contract ERC6909SupportsInterface is ERC6909Base {
    function test_supportsInterface() public view {
        assertTrue(erc6909.supportsInterface(type(IERC6909).interfaceId));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_supportsInterface(bytes4 randomInterface) public view {
        vm.assume(randomInterface != type(IERC6909).interfaceId);

        assertFalse(erc6909.supportsInterface(randomInterface));
    }
}
