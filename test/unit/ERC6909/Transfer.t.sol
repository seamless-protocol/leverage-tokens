// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";
import {ERC6909Harness} from "./harness/ERC6909Harness.sol";

contract ERC6909TransferTest is Test, ERC6909Base {
    function test_transfer() public {
        uint256 id = 1;
        address from = makeAddr("from");
        address to = makeAddr("to");
        uint256 senderBalance = 100 ether;
        uint256 receiverBalance = 50 ether;
        uint256 sendingAmount = 60 ether;

        _mint(from, id, senderBalance);
        _mint(to, id, receiverBalance);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(from, from, to, id, sendingAmount);

        vm.prank(from);
        erc6909.transfer(to, id, sendingAmount);

        assertEq(erc6909.balanceOf(from, id), senderBalance - sendingAmount);
        assertEq(erc6909.balanceOf(to, id), receiverBalance + sendingAmount);
        assertEq(erc6909.totalSupply(id), senderBalance + receiverBalance);
    }

    function testFuzz_transfer(uint128 senderBalance, uint128 receiverBalance, uint128 sendingAmount) public {
        vm.assume(sendingAmount < senderBalance);

        uint256 id = 1;
        address from = makeAddr("from");
        address to = makeAddr("to");

        _mint(from, id, senderBalance);
        _mint(to, id, receiverBalance);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(from, from, to, id, sendingAmount);

        vm.prank(from);
        erc6909.transfer(to, id, sendingAmount);

        assertEq(erc6909.balanceOf(from, id), senderBalance - sendingAmount);
        assertEq(erc6909.balanceOf(to, id), uint256(receiverBalance) + sendingAmount);
        assertEq(erc6909.totalSupply(id), uint256(senderBalance) + receiverBalance);
    }

    function testFuzz_transfer_RevertIf_NotEnoughBalance(uint256 senderBalance, uint256 amount) public {
        vm.assume(amount > senderBalance);

        uint256 id = 1;
        address from = makeAddr("from");
        address to = makeAddr("to");

        _mint(from, id, senderBalance);

        vm.expectRevert(abi.encodeWithSelector(IERC6909.InsufficientBalance.selector, from, id));
        vm.prank(from);
        erc6909.transfer(to, id, amount);
    }
}
