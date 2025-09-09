// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Internal imports
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {MockSwapper} from "../mock/MockSwapper.sol";

contract RedeemTest is LeverageRouterTest {
    function testFuzz_redeem_CollateralReceivedWithinSlippage(
        uint128 requiredCollateral,
        uint128 requiredDebt,
        uint128 requiredCollateralForSwap,
        uint128 excessDebt
    ) public {
        vm.assume(requiredDebt < requiredCollateral);

        uint256 mintShares = 10 ether; // Doesn't matter for this test as the deposit and redeem are mocked
        uint256 redeemShares = 5 ether; // Doesn't matter for this test as the deposit and redeem are mocked

        requiredCollateralForSwap = uint128(bound(requiredCollateralForSwap, 0, requiredCollateral));

        swapper.mockNextExactInputSwap(collateralToken, debtToken, uint256(requiredDebt) + excessDebt);
        _mockLeverageManagerRedeem(
            requiredCollateral, requiredDebt, redeemShares, requiredCollateral - requiredCollateralForSwap
        );

        uint256 collateralFromSender = requiredCollateral - requiredDebt;
        _deposit(
            collateralFromSender, // 1:1 exchange rate, 2x leverage
            requiredCollateral,
            requiredDebt,
            requiredCollateral - collateralFromSender,
            mintShares
        );

        ISwapAdapter.Call[] memory calls = new ISwapAdapter.Call[](2);
        calls[0] = ISwapAdapter.Call({
            target: address(collateralToken),
            data: abi.encodeWithSelector(IERC20.approve.selector, address(swapper), requiredCollateralForSwap),
            value: 0
        });
        calls[1] = ISwapAdapter.Call({
            target: address(swapper),
            data: abi.encodeWithSelector(MockSwapper.swapExactInput.selector, collateralToken, requiredCollateralForSwap),
            value: 0
        });

        // Execute the redeem
        leverageToken.approve(address(leverageRouter), redeemShares);
        leverageRouter.redeem(
            leverageToken, redeemShares, requiredCollateral - requiredCollateralForSwap, swapAdapter, calls
        );

        // Senders shares are burned
        assertEq(leverageToken.balanceOf(address(this)), mintShares - redeemShares);

        // The LeverageRouter has the required debt to repay the flash loan and Morpho is approved to spend it
        assertEq(debtToken.balanceOf(address(leverageRouter)), requiredDebt);
        assertEq(debtToken.allowance(address(leverageRouter), address(morpho)), requiredDebt);

        // Sender receives the remaining collateral
        assertEq(collateralToken.balanceOf(address(this)), requiredCollateral - requiredCollateralForSwap);
        assertEq(collateralToken.balanceOf(address(leverageRouter)), 0);

        // Sender receives any surplus debt from the swap
        assertEq(debtToken.balanceOf(address(this)), excessDebt);
    }

    function testFuzz_redeem_RevertIf_CollateralReceivedOutsideSlippage(
        uint128 requiredCollateral,
        uint128 requiredDebt,
        uint128 requiredCollateralForSwap,
        uint128 excessDebt
    ) public {
        vm.assume(requiredDebt < requiredCollateral);

        uint256 mintShares = 10 ether; // Doesn't matter for this test as the deposit and redeem are mocked
        uint256 redeemShares = 5 ether; // Doesn't matter for this test as the deposit and redeem are mocked

        requiredCollateralForSwap = uint128(bound(requiredCollateralForSwap, 0, requiredCollateral));

        // +1 more than the collateral received to trigger the revert
        uint256 minCollateral = uint256(requiredCollateral) - requiredCollateralForSwap + 1;

        swapper.mockNextExactInputSwap(collateralToken, debtToken, uint256(requiredDebt) + excessDebt);
        _mockLeverageManagerRedeem(requiredCollateral, requiredDebt, redeemShares, minCollateral);

        uint256 collateralFromSender = requiredCollateral - requiredDebt;
        _deposit(
            collateralFromSender, // 1:1 exchange rate, 2x leverage
            requiredCollateral,
            requiredDebt,
            requiredCollateral - collateralFromSender,
            mintShares
        );

        ISwapAdapter.Call[] memory calls = new ISwapAdapter.Call[](2);
        calls[0] = ISwapAdapter.Call({
            target: address(collateralToken),
            data: abi.encodeWithSelector(IERC20.approve.selector, address(swapper), requiredCollateralForSwap),
            value: 0
        });
        calls[1] = ISwapAdapter.Call({
            target: address(swapper),
            data: abi.encodeWithSelector(MockSwapper.swapExactInput.selector, collateralToken, requiredCollateralForSwap),
            value: 0
        });

        // Execute the redeem
        leverageToken.approve(address(leverageRouter), redeemShares);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageRouter.CollateralSlippageTooHigh.selector, minCollateral - 1, minCollateral)
        );
        leverageRouter.redeem(leverageToken, redeemShares, minCollateral, swapAdapter, calls);
    }

    function test_Redeem_RevertIf_Reentrancy() public {
        // Doesn't matter for this test, but we need to mock it still to avoid a revert before the
        // reentrancy guard is triggered
        _mockLeverageManagerRedeem(0, 0, 0, 0);

        ISwapAdapter.Call[] memory calls = new ISwapAdapter.Call[](1);
        calls[0] = ISwapAdapter.Call({
            target: address(leverageRouter),
            data: abi.encodeWithSelector(ILeverageRouter.redeem.selector, leverageToken, 0, 0, swapAdapter, calls),
            value: 0
        });

        // Execute the redeem
        leverageToken.approve(address(leverageRouter), 0);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        leverageRouter.redeem(leverageToken, 0, 0, swapAdapter, calls);
    }
}
