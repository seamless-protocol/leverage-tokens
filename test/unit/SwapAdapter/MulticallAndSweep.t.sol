// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IMulticallExecutor} from "src/interfaces/periphery/IMulticallExecutor.sol";
import {MulticallExecutor} from "src/periphery/MulticallExecutor.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockSwapper} from "../mock/MockSwapper.sol";

contract MulticallAndSweepTest is Test {
    IMulticallExecutor public multicallExecutor;

    MockSwapper public mockSwapper;

    MockERC20 public tokenA;

    MockERC20 public tokenB;

    FreeETH public freeETH;

    address public alice = makeAddr("alice");

    function setUp() public {
        multicallExecutor = new MulticallExecutor();
        mockSwapper = new MockSwapper();

        tokenA = new MockERC20();
        tokenB = new MockERC20();

        freeETH = new FreeETH();
    }

    function test_multicallAndSweep() public {
        uint256[] memory outputAmounts = new uint256[](2);
        outputAmounts[0] = 10;
        outputAmounts[1] = 5;

        mockSwapper.mockNextExactInputSwap(tokenA, tokenB, outputAmounts[0]);
        mockSwapper.mockNextExactInputSwap(tokenA, tokenB, outputAmounts[1]);

        uint256[] memory inputAmounts = new uint256[](2);
        inputAmounts[0] = 100;
        inputAmounts[1] = 50;

        IMulticallExecutor.Call[] memory calls = new IMulticallExecutor.Call[](5);
        // Approve MockSwapper to spend inputAmounts[0] of tokenA
        calls[0] = IMulticallExecutor.Call({
            target: address(tokenA),
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockSwapper), inputAmounts[0]),
            value: 0
        });
        // Swap inputAmounts[0] of tokenA to outputAmounts[0] of tokenB
        calls[1] = IMulticallExecutor.Call({
            target: address(mockSwapper),
            data: abi.encodeWithSelector(MockSwapper.swapExactInput.selector, tokenA, inputAmounts[0]),
            value: 0
        });
        // Approve MockSwapper to spend inputAmounts[1] of tokenA
        calls[2] = IMulticallExecutor.Call({
            target: address(tokenA),
            data: abi.encodeWithSelector(IERC20.approve.selector, address(mockSwapper), inputAmounts[1]),
            value: 0
        });
        // Swap inputAmounts[1] of tokenA to outputAmounts[1] of tokenB
        calls[3] = IMulticallExecutor.Call({
            target: address(mockSwapper),
            data: abi.encodeWithSelector(MockSwapper.swapExactInput.selector, tokenA, inputAmounts[1]),
            value: 0
        });
        // Receive some free ETH (1 ether)
        calls[4] = IMulticallExecutor.Call({
            target: address(freeETH),
            data: abi.encodeWithSelector(FreeETH.freeETH.selector),
            value: 0
        });

        uint256 ethBalanceBefore = alice.balance;

        // Transfer the input tokens to the MulticallExecutor, more than required
        uint256 totalInputAmount = inputAmounts[0] + inputAmounts[1] + 5;
        deal(address(tokenA), address(this), totalInputAmount);
        tokenA.transfer(address(multicallExecutor), totalInputAmount);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;

        vm.prank(alice);
        multicallExecutor.multicallAndSweep(calls, tokens);

        // MulticallExecutor swept the input tokens, output tokens, and ETH
        assertEq(tokenA.balanceOf(address(multicallExecutor)), 0);
        assertEq(tokenB.balanceOf(address(multicallExecutor)), 0);
        assertEq(address(multicallExecutor).balance, 0);

        // Sender received the swept input tokens, output tokens, and ETH
        assertEq(tokenA.balanceOf(alice), totalInputAmount - inputAmounts[0] - inputAmounts[1]);
        assertEq(tokenB.balanceOf(alice), outputAmounts[0] + outputAmounts[1]);
        assertEq(alice.balance, ethBalanceBefore + 1 ether);
    }
}

contract FreeETH is Test {
    function freeETH() public {
        deal(address(this), 1 ether);
        payable(msg.sender).transfer(address(this).balance);
    }
}
