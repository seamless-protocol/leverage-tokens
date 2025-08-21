// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {IUniswapV2Router02} from "src/interfaces/periphery/IUniswapV2Router02.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

contract SwapAdapterTest is IntegrationTestBase {
    function testFork_execute_SwapTokensForExactTokens() public {
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        uint256 amountOut = 3378.387886e6;
        uint256 amountIn = 0.99999999991932932 ether;
        uint256 amountInExcess = 0.5 ether;
        uint256 amountInMax = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapTokensForExactTokens.selector,
                amountOut,
                amountInMax,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountInMax});

        deal(address(tokenIn), user, amountInMax);

        vm.startPrank(user);

        WETH.approve(address(swapAdapter), amountInMax);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(
            call, approval, address(tokenIn), address(tokenOut), user, abi.encode(expectedResult)
        );

        bytes memory result =
            swapAdapter.execute(call, approval, address(tokenIn), address(tokenOut), amountInMax, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Excess input token should be returned to the user, since this was an exact output swap
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(tokenOut.balanceOf(address(swapAdapter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(swapAdapter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_execute_SwapExactTokensForTokens() public {
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        uint256 amountIn = 1 ether;
        uint256 amountInExcess = 0.5 ether;
        uint256 amountInTotal = amountIn + amountInExcess;
        uint256 expectedAmountOut = 3378.387886e6;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = expectedAmountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                amountIn,
                expectedAmountOut,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountInTotal);

        vm.startPrank(user);
        WETH.approve(address(swapAdapter), amountInTotal);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(
            call, approval, address(tokenIn), address(tokenOut), user, abi.encode(expectedResult)
        );

        bytes memory result =
            swapAdapter.execute(call, approval, address(tokenIn), address(tokenOut), amountInTotal, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the amountIn should be fully spent, and excess should be returned to the user
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(tokenOut.balanceOf(address(swapAdapter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(swapAdapter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_execute_SwapExactTokensForTokens_TransferAmountInBeforeExecute() public {
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 3378.387886e6;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = expectedAmountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                amountIn,
                expectedAmountOut,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);

        WETH.transfer(address(swapAdapter), amountIn);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(
            call, approval, address(tokenIn), address(tokenOut), user, abi.encode(expectedResult)
        );

        // inputAmount set to 0 on the execute call, because the input token was already transferred to the swap adapter
        bytes memory result = swapAdapter.execute(call, approval, address(tokenIn), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the input token should be fully spent
        assertEq(tokenIn.balanceOf(user), 0);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(tokenOut.balanceOf(address(swapAdapter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(swapAdapter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_execute_SwapExactETHForTokens() public {
        // UniswapV2Router02 expects WETH as the first token in the path for swapExactETHForTokens (reverts otherwise)
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        uint256 amountIn = 1 ether;
        uint256 amountInExcess = 0.5 ether;
        uint256 amountInTotal = amountIn + amountInExcess;
        uint256 expectedAmountOut = 3378.387886e6;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = expectedAmountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: amountIn,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactETHForTokens.selector,
                expectedAmountOut,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(user, amountInTotal);

        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(call, approval, address(0), address(tokenOut), user, abi.encode(expectedResult));

        bytes memory result =
            swapAdapter.execute{value: amountIn}(call, approval, address(0), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the amountIn should be fully spent, and excess should be returned to the user
        assertEq(user.balance, amountInExcess);
        assertEq(address(swapAdapter).balance, 0);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(tokenOut.balanceOf(address(swapAdapter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(swapAdapter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_execute_SwapETHForExactTokens() public {
        // UniswapV2Router02 expects WETH as the first token in the path for swapETHForExactTokens (reverts otherwise)
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        uint256 amountOut = 3378.387886e6;
        uint256 amountIn = 0.99999999991932932 ether;
        uint256 amountInExcess = 0.5 ether;
        uint256 amountInTotal = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: amountIn,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapETHForExactTokens.selector, amountOut, path, address(swapAdapter), block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(0), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(user, amountInTotal);

        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(call, approval, address(0), address(tokenOut), user, abi.encode(expectedResult));

        bytes memory result =
            swapAdapter.execute{value: amountIn}(call, approval, address(0), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Excess ETH should be returned to the user
        assertEq(user.balance, amountInExcess);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(address(swapAdapter).balance, 0);
        assertEq(tokenOut.balanceOf(address(swapAdapter)), 0);
    }

    function testFork_execute_SwapTokensForExactETH() public {
        IERC20 tokenIn = USDC;
        // UniswapV2Router02 expects WETH as the last token in the path for swapTokensForExactETH (reverts otherwise)
        IERC20 tokenOut = WETH;

        uint256 amountOut = 1 ether;
        uint256 amountIn = 3402.02492e6;
        uint256 amountInExcess = 100e6;
        uint256 amountInTotal = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapTokensForExactETH.selector,
                amountOut,
                amountInTotal,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountInTotal});

        deal(address(tokenIn), user, amountInTotal);

        vm.startPrank(user);

        USDC.approve(address(swapAdapter), amountInTotal);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(call, approval, address(tokenIn), address(0), user, abi.encode(expectedResult));

        bytes memory result =
            swapAdapter.execute(call, approval, address(tokenIn), address(0), amountInTotal, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(user.balance, amountOut);

        // Excess input token should be returned to the user, since this was an exact output swap
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(address(swapAdapter).balance, 0);
    }

    function testFork_execute_SwapExactTokensForETH() public {
        IERC20 tokenIn = USDC;
        IERC20 tokenOut = WETH;

        uint256 amountIn = 3402.02492e6;
        uint256 amountOut = 1.000000000115587537 ether;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForETH.selector,
                amountIn,
                amountOut,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);

        USDC.approve(address(swapAdapter), amountIn);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(call, approval, address(tokenIn), address(0), user, abi.encode(expectedResult));

        bytes memory result = swapAdapter.execute(call, approval, address(tokenIn), address(0), amountIn, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(user.balance, amountOut);

        // Because this was an exact input swap, the input token should be fully spent
        assertEq(tokenIn.balanceOf(user), 0);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(address(swapAdapter).balance, 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(swapAdapter), UNISWAP_V2_ROUTER02), 0);
    }
}
