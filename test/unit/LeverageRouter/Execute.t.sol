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

contract ExecuteTest is LeverageRouterTest {
    MockUniswapV2Router02 public mockUniswapV2Router02;

    function setUp() public override {
        super.setUp();

        mockUniswapV2Router02 = new MockUniswapV2Router02();
    }

    function test_execute() public {
        IERC20 tokenIn = collateralToken;
        IERC20 tokenOut = debtToken;
        uint256 amountIn = 1 ether;
        uint256 amountInExcess = 0.5 ether;
        uint256 tokenInBalance = amountIn + amountInExcess;
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

        deal(address(tokenIn), address(leverageRouter), tokenInBalance);

        bytes memory result = leverageRouter.exposed_execute(call, approval);

        // Check the swap result
        uint256[] memory resultDecoded = abi.decode(result, (uint256[]));
        assertEq(resultDecoded[0], expectedResult[0]);
        assertEq(resultDecoded[1], expectedResult[1]);

        // The output asset should still be in the LeverageRouter
        assertEq(tokenOut.balanceOf(address(leverageRouter)), expectedAmountOut);

        // Excess input token should still be in the LeverageRouter
        assertEq(tokenIn.balanceOf(address(leverageRouter)), amountInExcess);

        // Allowance should be reset to zero
        assertEq(tokenIn.allowance(address(leverageRouter), address(mockUniswapV2Router02)), 0);
    }

    function test_execute_RevertIf_ExternalCallRevertsBubblesUp() public {
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
