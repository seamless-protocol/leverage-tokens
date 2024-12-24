// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";
import {ERC6909Harness} from "./harness/ERC6909Harness.sol";

contract ERC6909MintTest is Test, ERC6909Base {
    function test_mint() public {
        uint256 id = 1;
        uint256 amount = 100 ether;
        address to = makeAddr("to");

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(address(this), address(0), to, id, amount);

        erc6909.mint(to, id, amount);

        assertEq(erc6909.balanceOf(to, id), amount);
        assertEq(erc6909.totalSupply(id), amount);
    }

    function testFuzz_mint(uint256 id, uint128 balanceBefore, uint128 amount, address to) public {
        // Prepare state
        _mint(to, id, balanceBefore);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(address(this), address(0), to, id, amount);

        erc6909.mint(to, id, amount);

        uint256 expectedBalance = uint256(balanceBefore) + uint256(amount);

        assertEq(erc6909.balanceOf(to, id), expectedBalance);
        assertEq(erc6909.totalSupply(id), expectedBalance);
    }
}
