// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ERC6909Base} from "./ERC6909Base.t.sol";
import {IERC6909} from "src/interfaces/IERC6909.sol";
import {ERC6909Harness} from "./harness/ERC6909Harness.sol";

contract ERC6909TransferFromTest is Test, ERC6909Base {
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
        erc6909.transferFrom(from, to, id, sendingAmount);

        assertEq(erc6909.balanceOf(from, id), senderBalance - sendingAmount);
        assertEq(erc6909.balanceOf(to, id), uint256(receiverBalance) + sendingAmount);
        assertEq(erc6909.totalSupply(id), uint256(senderBalance) + receiverBalance);
    }

    function testFuzz_transferFrom_CallerIsOperator(
        uint128 senderBalance,
        uint128 receiverBalance,
        uint128 sendingAmount
    ) public {
        vm.assume(sendingAmount < senderBalance);

        uint256 id = 1;
        address from = makeAddr("from");
        address to = makeAddr("to");

        _mint(from, id, senderBalance);
        _mint(to, id, receiverBalance);

        vm.prank(from);
        erc6909.setOperator(address(this), true);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(address(this), from, to, id, sendingAmount);
        erc6909.transferFrom(from, to, id, sendingAmount);

        assertEq(erc6909.balanceOf(from, id), senderBalance - sendingAmount);
        assertEq(erc6909.balanceOf(to, id), uint256(receiverBalance) + sendingAmount);
        assertEq(erc6909.totalSupply(id), uint256(senderBalance) + receiverBalance);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_transferFrom_CallerIsApproved(
        uint128 senderBalance,
        uint128 receiverBalance,
        uint128 sendingAmount,
        uint128 approvedAmount
    ) public {
        vm.assume(sendingAmount < senderBalance);
        vm.assume(approvedAmount >= sendingAmount);

        uint256 id = 1;
        address from = makeAddr("from");
        address to = makeAddr("to");

        _mint(from, id, senderBalance);
        _mint(to, id, receiverBalance);

        vm.prank(from);
        erc6909.approve(address(this), id, approvedAmount);

        vm.expectEmit(true, true, true, true);
        emit IERC6909.Transfer(address(this), from, to, id, sendingAmount);

        erc6909.transferFrom(from, to, id, sendingAmount);

        assertEq(erc6909.allowance(from, address(this), id), approvedAmount - sendingAmount);
        assertEq(erc6909.balanceOf(from, id), senderBalance - sendingAmount);
        assertEq(erc6909.balanceOf(to, id), uint256(receiverBalance) + sendingAmount);
        assertEq(erc6909.totalSupply(id), uint256(senderBalance) + receiverBalance);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_transferFrom_RevertIf_InsufficientAllowance(uint128 sendingAmount, uint128 allowance) public {
        vm.assume(allowance < sendingAmount);

        uint256 id = 1;
        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(from);
        erc6909.approve(address(this), id, allowance);

        vm.expectRevert(abi.encodeWithSelector(IERC6909.InsufficientPermission.selector, address(this), id));
        erc6909.transferFrom(from, to, id, sendingAmount);
    }
}
