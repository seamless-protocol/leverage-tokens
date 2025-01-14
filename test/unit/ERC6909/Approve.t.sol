// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";
import {ERC6909Harness} from "./harness/ERC6909Harness.sol";

contract ERC6909ApproveTest is Test, ERC6909Base {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_Approve(address user, address spender, uint256 strategyId, uint256 amount) public {
        vm.expectEmit(true, true, true, true);
        emit IERC6909.Approval(user, spender, strategyId, amount);

        vm.prank(user);
        erc6909.approve(spender, strategyId, amount);

        assertEq(erc6909.allowance(user, spender, strategyId), amount);
    }
}
