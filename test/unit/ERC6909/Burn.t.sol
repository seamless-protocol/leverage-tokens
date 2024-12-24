// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";
import {ERC6909Harness} from "./harness/ERC6909Harness.sol";

contract ERC6909BurnTest is Test, ERC6909Base {
    function test_burn() public {
        uint256 id = 1;
        uint256 balanceBefore = 100 ether;
        uint256 burnAmount = 60 ether;
        address from = makeAddr("from");

        _mint(from, id, balanceBefore);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(address(this), from, address(0), id, burnAmount);

        erc6909.burn(from, id, burnAmount);

        assertEq(erc6909.balanceOf(from, id), balanceBefore - burnAmount);
        assertEq(erc6909.totalSupply(id), balanceBefore - burnAmount);
    }

    function testFuzz_burn(uint256 id, uint256 balanceBefore, uint256 amount, address from) public {
        vm.assume(amount <= balanceBefore);

        _mint(from, id, balanceBefore);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(address(this), from, address(0), id, amount);

        erc6909.burn(from, id, amount);

        uint256 expectedBalance = balanceBefore - amount;

        assertEq(erc6909.balanceOf(from, id), expectedBalance);
        assertEq(erc6909.totalSupply(id), expectedBalance);
    }

    function testFuzz_burn_RevertIf_NotEnoughBalance(uint256 id, uint256 balanceBefore, uint256 amount, address from)
        public
    {
        vm.assume(amount > balanceBefore);

        _mint(from, id, balanceBefore);

        vm.expectRevert(abi.encodeWithSelector(IERC6909.InsufficientBalance.selector, from, id));
        erc6909.burn(from, id, amount);
    }
}
