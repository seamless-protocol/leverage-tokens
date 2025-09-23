// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IMulticallExecutor} from "src/interfaces/periphery/IMulticallExecutor.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {LeverageRouterHarness} from "../harness/LeverageRouterHarness.t.sol";

contract NonReentrantTest is LeverageRouterTest {
    function test_nonReentrant_RevertIf_Reentrancy() public {
        uint256 requiredCollateral = 10 ether;
        uint256 collateralFromSender = 5 ether;
        uint256 debtFlashLoan = 1 ether;
        uint256 requiredCollateralFromSwap = requiredCollateral - collateralFromSender;
        uint256 collateralReceivedFromDebtSwap = requiredCollateralFromSwap;
        uint256 shares = 10 ether;
        uint256 totalCollateral = collateralFromSender + collateralReceivedFromDebtSwap;

        _mockLeverageManagerDeposit(totalCollateral, debtFlashLoan, collateralReceivedFromDebtSwap, shares);

        IMulticallExecutor.Call[] memory calls = new IMulticallExecutor.Call[](1);

        // Check reentrancy guard on deposit
        calls[0] = IMulticallExecutor.Call({
            target: address(leverageRouter),
            data: abi.encodeWithSelector(
                ILeverageRouter.deposit.selector,
                leverageToken,
                collateralFromSender,
                debtFlashLoan,
                shares,
                multicallExecutor,
                calls
            ),
            value: 0
        });

        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);

        // Transient storage for reentrancy guard is false outside of any tx execution stack on the LeverageManager
        assertEq(LeverageRouterHarness(address(leverageRouter)).exposed_getReentrancyGuardTransientStorage(), false);

        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        leverageRouter.deposit(leverageToken, collateralFromSender, debtFlashLoan, shares, multicallExecutor, calls);

        // Sanity check: Transient storage slot is reset to false
        assertEq(LeverageRouterHarness(address(leverageRouter)).exposed_getReentrancyGuardTransientStorage(), false);

        // Check reentrancy guard on redeem
        calls[0] = IMulticallExecutor.Call({
            target: address(leverageRouter),
            data: abi.encodeWithSelector(ILeverageRouter.redeem.selector, leverageToken, 0, 0, multicallExecutor, calls),
            value: 0
        });
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        leverageRouter.deposit(leverageToken, collateralFromSender, debtFlashLoan, shares, multicallExecutor, calls);

        // Sanity check: Transient storage slot is reset to false
        assertEq(LeverageRouterHarness(address(leverageRouter)).exposed_getReentrancyGuardTransientStorage(), false);

        // Check reentrancy guard on redeemWithVelora
        calls[0] = IMulticallExecutor.Call({
            target: address(leverageRouter),
            data: abi.encodeWithSelector(
                ILeverageRouter.redeemWithVelora.selector,
                leverageToken,
                0,
                0,
                IVeloraAdapter(address(veloraAdapter)),
                address(0),
                IVeloraAdapter.Offsets(0, 0, 0),
                new bytes(0)
            ),
            value: 0
        });
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        leverageRouter.deposit(leverageToken, collateralFromSender, debtFlashLoan, shares, multicallExecutor, calls);

        // Sanity check: Transient storage slot is reset to false
        assertEq(LeverageRouterHarness(address(leverageRouter)).exposed_getReentrancyGuardTransientStorage(), false);
    }
}
