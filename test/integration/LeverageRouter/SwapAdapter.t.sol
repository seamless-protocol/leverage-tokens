// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {IUniswapV2Router02} from "src/interfaces/periphery/IUniswapV2Router02.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";

contract SwapAdapterTest is LeverageRouterTest {
    function testFork_execute_SwapUniswapV2() public {
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        uint256 amountIn = 1 ether;
        uint256 expectedAmountOut = 3378.387886e6;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: UNISWAP_V2_ROUTER02,
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                amountIn,
                0,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: UNISWAP_V2_ROUTER02, amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        WETH.approve(address(swapAdapter), amountIn);
        bytes memory result = swapAdapter.execute(call, approval, address(tokenIn), address(tokenOut), payable(user));
        vm.stopPrank();

        assertEq(USDC.balanceOf(user), expectedAmountOut);
        assertEq(USDC.balanceOf(address(swapAdapter)), 0);

        uint256[] memory amounts = abi.decode(result, (uint256[]));
        assertEq(amounts[0], amountIn);
        assertEq(amounts[1], expectedAmountOut);
    }
}
