// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {IUniswapV2Router02} from "src/interfaces/periphery/IUniswapV2Router02.sol";
import {SwapAdapterTest} from "./SwapAdapter.t.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockUniswapV2Router02} from "test/unit/mock/MockUniswapV2Router02.sol";

contract ExecuteTest is SwapAdapterTest {
    IERC20 public WETH;
    IERC20 public USDC;

    address public user;

    function setUp() public override {
        super.setUp();

        WETH = new MockERC20();
        USDC = new MockERC20();

        user = makeAddr("user");
    }

    function testFuzz_execute_SwapUniswapV2_ExactInput(uint256 amountIn, uint256 expectedAmountOut) public {
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = expectedAmountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        mockUniswapV2Router02.mockNextUniswapV2Swap(
            MockUniswapV2Router02.MockV2Swap({
                fromToken: tokenIn,
                toToken: tokenOut,
                fromAmount: amountIn,
                toAmount: expectedAmountOut,
                encodedPath: keccak256(abi.encode(path)),
                isExecuted: false
            })
        );

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: address(mockUniswapV2Router02),
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
            ISwapAdapter.Approval({token: address(tokenIn), spender: address(mockUniswapV2Router02), amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        WETH.approve(address(swapAdapter), amountIn);

        vm.expectEmit(true, true, true, true);
        emit ISwapAdapter.Executed(
            call, approval, address(tokenIn), address(tokenOut), user, abi.encode(expectedResult)
        );

        bytes memory result =
            swapAdapter.execute(call, approval, address(tokenIn), address(tokenOut), amountIn, payable(user));
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
        assertEq(tokenIn.allowance(address(swapAdapter), address(mockUniswapV2Router02)), 0);
    }

    function testFuzz_execute_SwapUniswapV2_ExactOutput(uint256 amountOut, uint256 amountIn, uint256 amountInExcess)
        public
    {
        IERC20 tokenIn = WETH;
        IERC20 tokenOut = USDC;
        amountInExcess = bound(amountInExcess, 0, type(uint256).max - amountIn);
        uint256 amountInMax = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        mockUniswapV2Router02.mockNextUniswapV2Swap(
            MockUniswapV2Router02.MockV2Swap({
                fromToken: tokenIn,
                toToken: tokenOut,
                fromAmount: amountIn,
                toAmount: amountOut,
                encodedPath: keccak256(abi.encode(path)),
                isExecuted: false
            })
        );

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: address(mockUniswapV2Router02),
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

        ISwapAdapter.Approval memory approval = ISwapAdapter.Approval({
            token: address(tokenIn),
            spender: address(mockUniswapV2Router02),
            amount: amountInMax
        });

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
        assertEq(tokenIn.allowance(address(swapAdapter), address(mockUniswapV2Router02)), 0);
    }

    function test_execute_SwapUniswapV2_ExactInputForETH() public {
        IERC20 tokenIn = USDC;
        IERC20 tokenOut = IERC20(address(0)); // Use address 0 for ETH

        uint256 amountIn = 100 ether;
        uint256 expectedAmountOut = 1 ether;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = expectedAmountOut;

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        mockUniswapV2Router02.mockNextUniswapV2Swap(
            MockUniswapV2Router02.MockV2Swap({
                fromToken: tokenIn,
                toToken: tokenOut,
                fromAmount: amountIn,
                toAmount: expectedAmountOut,
                encodedPath: keccak256(abi.encode(path)),
                isExecuted: false
            })
        );

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: address(mockUniswapV2Router02),
            value: 0,
            data: abi.encodeWithSelector(
                MockUniswapV2Router02.swapExactTokensForETH.selector,
                amountIn,
                expectedAmountOut,
                path,
                address(swapAdapter),
                block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(tokenIn), spender: address(mockUniswapV2Router02), amount: amountIn});

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        USDC.approve(address(swapAdapter), amountIn);

        bytes memory result =
            swapAdapter.execute(call, approval, address(tokenIn), address(tokenOut), amountIn, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(user.balance, expectedAmountOut);

        // Because this was an exact input swap, the input token should be fully spent
        assertEq(tokenIn.balanceOf(user), 0);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(tokenIn.balanceOf(address(swapAdapter)), 0);
        assertEq(address(swapAdapter).balance, 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(swapAdapter), address(mockUniswapV2Router02)), 0);
    }

    function test_execute_SwapUniswapV2_ETHForExactTokens() public {
        uint256 amountOut = 100 ether;
        uint256 amountIn = 1 ether;
        uint256 amountInExcess = 0.2 ether;
        uint256 amountInMax = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = address(USDC);

        mockUniswapV2Router02.mockNextUniswapV2Swap(
            MockUniswapV2Router02.MockV2Swap({
                fromToken: IERC20(address(0)),
                toToken: USDC,
                fromAmount: amountIn,
                toAmount: amountOut,
                encodedPath: keccak256(abi.encode(path)),
                isExecuted: false
            })
        );

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: address(mockUniswapV2Router02),
            value: amountInMax,
            data: abi.encodeWithSelector(
                MockUniswapV2Router02.swapETHForExactTokens.selector, amountOut, path, address(swapAdapter), block.timestamp
            )
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(0), spender: address(0), amount: 0});

        deal(user, amountInMax);

        vm.startPrank(user);
        bytes memory result =
            swapAdapter.execute{value: amountInMax}(call, approval, address(0), address(USDC), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(USDC.balanceOf(user), amountOut);

        // Some leftover ETH should be returned to the user
        assertEq(address(user).balance, amountInExcess);

        // No tokenIn or tokenOut should be left in the swap adapter
        assertEq(address(swapAdapter).balance, 0);
    }

    function test_execute_RevertIf_ExternalCallReverts() public {
        TestRevertContract testRevertContract = new TestRevertContract();

        ISwapAdapter.Call memory call = ISwapAdapter.Call({
            target: address(testRevertContract),
            value: 0,
            data: abi.encodeWithSelector(TestRevertContract.revertWithMessage.selector)
        });

        ISwapAdapter.Approval memory approval =
            ISwapAdapter.Approval({token: address(0), spender: address(0), amount: 0});

        vm.expectRevert("test revert message");
        swapAdapter.execute(call, approval, address(0), address(0), 0, payable(address(0)));

        call = ISwapAdapter.Call({
            target: address(testRevertContract),
            value: 0,
            data: abi.encodeWithSelector(TestRevertContract.revertWithNamedError.selector)
        });

        vm.expectRevert(abi.encodeWithSelector(TestRevertContract.TestError.selector, 12345, address(0xBEEF)));
        swapAdapter.execute(call, approval, address(0), address(0), 0, payable(address(0)));
    }
}

contract TestRevertContract {
    error TestError(uint256, address);

    function revertWithMessage() public pure {
        revert("test revert message");
    }

    function revertWithNamedError() public pure {
        revert TestError(12345, address(0xBEEF));
    }
}
