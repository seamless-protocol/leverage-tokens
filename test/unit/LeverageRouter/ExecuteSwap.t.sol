// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IUniswapV2Router02} from "src/interfaces/periphery/IUniswapV2Router02.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockUniswapV2Router02} from "test/unit/mock/MockUniswapV2Router02.sol";

contract ExecuteSwapTest is LeverageRouterTest {
    MockUniswapV2Router02 public mockUniswapV2Router02;

    address public user;

    function setUp() public override {
        super.setUp();

        mockUniswapV2Router02 = new MockUniswapV2Router02();

        user = makeAddr("user");
    }

    function testFuzz_executeSwap_SwapExactTokensForTokens(uint256 amountIn, uint256 expectedAmountOut) public {
        IERC20 tokenIn = collateralToken;
        IERC20 tokenOut = debtToken;

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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
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

        ILeverageRouter.Approval memory approval = ILeverageRouter.Approval({
            token: address(tokenIn),
            spender: address(mockUniswapV2Router02),
            amount: amountIn
        });

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(leverageRouter), amountIn);

        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(tokenOut), amountIn, payable(user));
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
        assertEq(tokenIn.allowance(address(leverageRouter), address(mockUniswapV2Router02)), 0);
    }

    function testFuzz_executeSwap_SwapTokensForExactTokens(uint256 amountOut, uint256 amountIn, uint256 amountInExcess)
        public
    {
        IERC20 tokenIn = collateralToken;
        IERC20 tokenOut = debtToken;
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
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

        ILeverageRouter.Approval memory approval = ILeverageRouter.Approval({
            token: address(tokenIn),
            spender: address(mockUniswapV2Router02),
            amount: amountInMax
        });

        deal(address(tokenIn), user, amountInMax);

        vm.startPrank(user);

        tokenIn.approve(address(leverageRouter), amountInMax);

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
        assertEq(tokenIn.allowance(address(leverageRouter), address(mockUniswapV2Router02)), 0);
    }

    function testFuzz_executeSwap_SwapTokensForExactTokens_TransferAmountInBeforeExecute(
        uint256 amountOut,
        uint256 amountIn,
        uint256 amountInExcess
    ) public {
        IERC20 tokenIn = collateralToken;
        IERC20 tokenOut = debtToken;
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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
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

        ILeverageRouter.Approval memory approval = ILeverageRouter.Approval({
            token: address(tokenIn),
            spender: address(mockUniswapV2Router02),
            amount: amountInMax
        });

        deal(address(tokenIn), user, amountInMax);

        vm.startPrank(user);

        // Transfer the input token to the LeverageRouter before executing
        tokenIn.transfer(address(leverageRouter), amountInMax);

        // Set input amount (which is transferred in) to 0
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
        assertEq(tokenIn.allowance(address(leverageRouter), address(mockUniswapV2Router02)), 0);
    }

    function testFuzz_executeSwap_SwapExactTokensForTokens_TransferAmountInBeforeExecute(
        uint256 amountOut,
        uint256 amountIn,
        uint256 amountInExcess
    ) public {
        amountInExcess = bound(amountInExcess, 0, type(uint256).max - amountIn);
        IERC20 tokenIn = collateralToken;
        IERC20 tokenOut = debtToken;

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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                amountIn,
                amountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval = ILeverageRouter.Approval({
            token: address(tokenIn),
            spender: address(mockUniswapV2Router02),
            amount: amountIn
        });

        deal(address(tokenIn), user, amountIn + amountInExcess);

        vm.startPrank(user);

        // Transfer the input token to the LeverageRouter before executing
        tokenIn.transfer(address(leverageRouter), amountIn + amountInExcess);

        // Set input amount (which is transferred in) to 0
        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(tokenOut), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(tokenOut.balanceOf(user), amountOut);

        // Because this was an exact input swap, the input token should be fully spent, and any excess should be returned to the user
        assertEq(tokenIn.balanceOf(user), amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(tokenOut.balanceOf(address(leverageRouter)), 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), address(mockUniswapV2Router02)), 0);
    }

    function testFuzz_executeSwap_SwapExactTokensForETH(uint256 amountIn, uint256 expectedAmountOut) public {
        IERC20 tokenIn = debtToken;
        IERC20 tokenOut = IERC20(address(0)); // Use address 0 for ETH

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

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
            value: 0,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForETH.selector,
                amountIn,
                expectedAmountOut,
                path,
                address(leverageRouter),
                block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval = ILeverageRouter.Approval({
            token: address(tokenIn),
            spender: address(mockUniswapV2Router02),
            amount: amountIn
        });

        deal(address(tokenIn), user, amountIn);

        vm.startPrank(user);
        tokenIn.approve(address(leverageRouter), amountIn);

        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(tokenIn), address(tokenOut), amountIn, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(user.balance, expectedAmountOut);

        // Because this was an exact input swap, the input token should be fully spent
        assertEq(tokenIn.balanceOf(user), 0);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), 0);
        assertEq(address(leverageRouter).balance, 0);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), address(mockUniswapV2Router02)), 0);
    }

    function testFuzz_executeSwap_SwapETHForExactTokens(uint256 amountOut, uint256 amountIn, uint256 amountInExcess)
        public
    {
        amountInExcess = bound(amountInExcess, 0, type(uint256).max - amountIn);
        uint256 amountInMax = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = address(debtToken);

        mockUniswapV2Router02.mockNextUniswapV2Swap(
            MockUniswapV2Router02.MockV2Swap({
                fromToken: IERC20(address(0)),
                toToken: debtToken,
                fromAmount: amountIn,
                toAmount: amountOut,
                encodedPath: keccak256(abi.encode(path)),
                isExecuted: false
            })
        );

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
            value: amountInMax,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapETHForExactTokens.selector, amountOut, path, address(leverageRouter), block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(0), spender: address(0), amount: 0});

        deal(user, amountInMax);

        vm.startPrank(user);

        bytes memory result = leverageRouter.executeSwap{value: amountInMax}(
            call, approval, address(0), address(debtToken), 0, payable(user)
        );
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(debtToken.balanceOf(user), amountOut);

        // Some leftover ETH should be returned to the user
        assertEq(address(user).balance, amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(address(leverageRouter).balance, 0);
    }

    function testFuzz_executeSwap_SwapETHForExactTokens_TransferAmountInBeforeExecute(
        uint256 amountOut,
        uint256 amountIn,
        uint256 amountInExcess
    ) public {
        amountInExcess = bound(amountInExcess, 0, type(uint256).max - amountIn);
        uint256 amountInMax = amountIn + amountInExcess;

        uint256[] memory expectedResult = new uint256[](2);
        expectedResult[0] = amountIn;
        expectedResult[1] = amountOut;

        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = address(debtToken);

        mockUniswapV2Router02.mockNextUniswapV2Swap(
            MockUniswapV2Router02.MockV2Swap({
                fromToken: IERC20(address(0)),
                toToken: debtToken,
                fromAmount: amountIn,
                toAmount: amountOut,
                encodedPath: keccak256(abi.encode(path)),
                isExecuted: false
            })
        );

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(mockUniswapV2Router02),
            value: amountInMax,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapETHForExactTokens.selector, amountOut, path, address(leverageRouter), block.timestamp
            )
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(0), spender: address(0), amount: 0});

        deal(user, amountInMax);

        vm.startPrank(user);

        // Transfer amountInMax ETH to the LeverageRouter before executing
        payable(address(leverageRouter)).transfer(amountInMax);

        // Does not include ETH, as it was already sent beforehand
        bytes memory result =
            leverageRouter.executeSwap(call, approval, address(0), address(debtToken), 0, payable(user));
        vm.stopPrank();

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);
        assertEq(debtToken.balanceOf(user), amountOut);

        // Some leftover ETH should be returned to the user
        assertEq(address(user).balance, amountInExcess);

        // No tokenIn or tokenOut should be left in the LeverageRouter
        assertEq(address(leverageRouter).balance, 0);
    }

    function test_executeSwap_RevertIf_ExternalCallRevertsBubblesUp() public {
        TestRevertContract testRevertContract = new TestRevertContract();

        ILeverageRouter.Call memory call = ILeverageRouter.Call({
            target: address(testRevertContract),
            value: 0,
            data: abi.encodeWithSelector(TestRevertContract.revertWithMessage.selector)
        });

        ILeverageRouter.Approval memory approval =
            ILeverageRouter.Approval({token: address(0), spender: address(0), amount: 0});

        vm.expectRevert("test revert message");
        leverageRouter.executeSwap(call, approval, address(0), address(0), 0, payable(address(0)));

        call = ILeverageRouter.Call({
            target: address(testRevertContract),
            value: 0,
            data: abi.encodeWithSelector(TestRevertContract.revertWithNamedError.selector)
        });

        vm.expectRevert(abi.encodeWithSelector(TestRevertContract.TestError.selector, 12345, address(0xBEEF)));
        leverageRouter.executeSwap(call, approval, address(0), address(0), 0, payable(address(0)));
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
