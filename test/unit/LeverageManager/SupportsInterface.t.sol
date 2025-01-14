// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Internal imports
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";

contract LeverageManagerSupportsInterface is LeverageManagerBaseTest {
    function test_supportsInterface_ERC6909Interface() public view {
        assertTrue(leverageManager.supportsInterface(type(IERC6909).interfaceId));
    }

    function test_supportInterface_AccessControlInterface() public view {
        assertTrue(leverageManager.supportsInterface(type(IAccessControl).interfaceId));
    }

    function test_supportInterface_ERC165Interface() public view {
        assertTrue(leverageManager.supportsInterface(type(IERC165).interfaceId));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_supportsInterface(bytes4 randomInterface) public view {
        vm.assume(randomInterface != type(IERC6909).interfaceId);
        vm.assume(randomInterface != type(IAccessControl).interfaceId);
        vm.assume(randomInterface != type(IERC165).interfaceId);

        assertFalse(leverageManager.supportsInterface(randomInterface));
    }
}
