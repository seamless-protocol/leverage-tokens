// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IUniswapV2Router02} from "src/interfaces/periphery/IUniswapV2Router02.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";

contract LeverageRouterExecuteSwapTest is LeverageRouterTest {
    function testFork_executeSwap_SwapTokensForExactTokens() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapTokensForExactTokens.selector,
                amountOut,
                amountInMax,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountInMax});

        deal(address(tokenIn), user, amountInMax);

        vm.startPrank(user);

        WETH.approve(address(leverageRouter), amountInMax);

        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(tokenOut), amountInMax, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Excess input token should be returned to the user, since this was an exact output swap
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_executeSwap_SwapTokensForExactTokens_TransferAmountInBeforeExecute() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapTokensForExactTokens.selector,
                amountOut,
                amountInMax,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountInMax});

        deal(address(tokenIn), user, amountInMax);

        vm.startPrank(user);

        // Transfer the input token to the LeverageRouter before executing
        WETH.transfer(address(leverageRouter), amountInMax);

        // inputAmount set to 0 on the execute call, because the input token was already transferred to the LeverageRouter
        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Excess input token should be returned to the user, since this was an exact output swap
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_executeSwap_SwapExactTokensForTokens() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                amountIn,
                expectedAmountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountInTotal);

        vm.startPrank(user);
        WETH.approve(address(leverageRouter), amountInTotal);

        bytes memory result = leverageRouter.executeSwap(
            call, approval, address(tokenIn), address(tokenOut), amountInTotal, payable(user)
        );
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the amountIn should be fully spent, and excess should be returned to the user
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_executeSwap_SwapExactTokensForTokens_TransferAmountInBeforeExecute() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                amountIn,
                expectedAmountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);

        WETH.transfer(address(leverageRouter), amountIn);

        // inputAmount set to 0 on the execute call, because the input token was already transferred to the LeverageRouter
        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the input token should be fully spent
        assertEq(tokenIn.balanceOf(user), 0);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_executeSwap_SwapExactETHForTokens() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: amountIn,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactETHForTokens.selector,
                expectedAmountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(user, amountInTotal);

        vm.startPrank(user);

        bytes memory result =
            leverageRouter.executeSwap{value: amountIn}(call, approval, address(0), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the amountIn should be fully spent, and excess should be returned to the user
        assertEq(user.balance, amountInExcess);
        assertEq(address(leverageRouter).balance, 0);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_executeSwap_SwapExactETHForTokens_TransferAmountInBeforeExecute() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: amountIn,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactETHForTokens.selector,
                expectedAmountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(user, amountInTotal);

        vm.startPrank(user);

        // Transfer ETH to the LeverageRouter before executing
        payable(address(leverageRouter)).transfer(amountInTotal);

        // ETH is not included, as it was already transferred
        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(0), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), expectedAmountOut);

        // Because this was an exact input swap, the amountIn should be fully spent, and excess should be returned to the user
        assertEq(user.balance, amountInExcess);
        assertEq(address(leverageRouter).balance, 0);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }

    function testFork_executeSwap_SwapETHForExactTokens() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: amountIn,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapETHForExactTokens.selector, amountOut, path, address(leverageRouter), block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(0), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(user, amountInTotal);

        vm.startPrank(user);

        bytes memory result =
            leverageRouter.executeSwap{value: amountIn}(call, approval, address(0), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Excess ETH should be returned to the user
        assertEq(user.balance, amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(address(leverageRouter).balance, 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);
    }

    function testFork_executeSwap_SwapETHForExactTokens_TransferAmountInBeforeExecute() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: amountIn,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapETHForExactTokens.selector, amountOut, path, address(leverageRouter), block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(0), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(user, amountInTotal);

        vm.startPrank(user);

        // Transfer ETH to the LeverageRouter before executing
        payable(address(leverageRouter)).transfer(amountInTotal);

        // ETH is not included, as it was already transferred
        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(0), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Excess ETH should be returned to the user
        assertEq(user.balance, amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(address(leverageRouter).balance, 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);
    }

    function testFork_executeSwap_SwapTokensForExactETH() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapTokensForExactETH.selector,
                amountOut,
                amountInTotal,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountInTotal});

        deal(address(tokenIn), user, amountInTotal);

        vm.startPrank(user);

        USDC.approve(address(leverageRouter), amountInTotal);

        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(0), amountInTotal, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(user.balance, amountOut);

        // Excess input token should be returned to the user, since this was an exact output swap
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(address(leverageRouter).balance, 0);
    }

    function testFork_executeSwap_SwapExactTokensForETH() public {
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForETH.selector,
                amountIn,
                amountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);

        USDC.approve(address(leverageRouter), amountIn);

        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(0), amountIn, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(user.balance, amountOut);

        // Because this was an exact input swap, the input token should be fully spent
        assertEq(tokenIn.balanceOf(user), 0);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(address(leverageRouter).balance, 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), UNISWAP_V2_ROUTER02), 0);
    }
}
