// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";
import {ERC6909Harness} from "./harness/ERC6909Harness.sol";

contract ERC6909SetOperatorTest is Test, ERC6909Base {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_SetOperator(address user, address operator, bool isOperator) public {
        vm.prank(user);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.OperatorSet(user, operator, isOperator);

        erc6909.setOperator(operator, isOperator);

        assertEq(erc6909.isOperator(user, operator), isOperator);
    }
}
