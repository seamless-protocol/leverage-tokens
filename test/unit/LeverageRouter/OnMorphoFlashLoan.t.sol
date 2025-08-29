// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";

contract OnMorphoFlashLoanTest is LeverageRouterTest {
    function test_onMorphoFlashLoan_Deposit() public {
        uint256 requiredCollateral = 10 ether;
        uint256 collateralFromSender = 5 ether;
        uint256 collateralReceivedFromDebtSwap = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerDeposit(requiredCollateral, requiredDebt, collateralReceivedFromDebtSwap, shares);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            path: new address[](0),
            encodedPath: new bytes(0),
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchange: ISwapAdapter.Exchange.AERODROME,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        ILeverageRouter.Call[] memory calls = new ILeverageRouter.Call[](2);
        calls[0] = ILeverageRouter.Call({
            target: address(debtToken),
            data: abi.encodeWithSelector(IERC20.approve.selector, address(swapper), requiredDebt),
            value: 0
        });
        calls[1] = ILeverageRouter.Call({
            target: address(swapper),
            data: abi.encodeWithSelector(ISwapAdapter.swapExactInput.selector, debtToken, requiredDebt, 0, swapContext),
            value: 0
        });

        bytes memory depositData = abi.encode(
            ILeverageRouter.DepositParams({
                leverageToken: leverageToken,
                collateralFromSender: collateralFromSender,
                minShares: shares,
                sender: address(this),
                swapCalls: calls
            })
        );

        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);

        // Also mock morpho flash loaning the debt required for the deposit
        uint256 flashLoanAmount = requiredDebt;
        deal(address(debtToken), address(leverageRouter), flashLoanAmount);

        vm.prank(address(morpho));
        leverageRouter.onMorphoFlashLoan(
            flashLoanAmount,
            abi.encode(ILeverageRouter.MorphoCallbackData({action: ExternalAction.Mint, data: depositData}))
        );
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(debtToken.balanceOf(address(leverageRouter)), requiredDebt);
        assertEq(debtToken.allowance(address(leverageRouter), address(morpho)), requiredDebt);
    }

    function test_onMorphoFlashLoan_Redeem() public {
        uint256 requiredCollateral = 10 ether;
        uint256 collateralFromSender = 5 ether;
        uint256 collateralReceivedFromDebtSwap = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _deposit(collateralFromSender, requiredCollateral, requiredDebt, collateralReceivedFromDebtSwap, shares);

        uint256 requiredCollateralForSwap = requiredCollateral - collateralFromSender;
        _mockLeverageManagerRedeem(
            requiredCollateral,
            requiredDebt,
            requiredCollateralForSwap,
            shares,
            requiredCollateral - requiredCollateralForSwap
        );

        bytes memory redeemWithVeloraData = abi.encode(
            ILeverageRouter.RedeemWithVeloraParams({
                leverageToken: leverageToken,
                shares: shares,
                minCollateralForSender: requiredCollateral - requiredCollateralForSwap,
                sender: address(this),
                veloraAdapter: IVeloraAdapter(address(veloraAdapter)),
                augustus: address(0),
                offsets: IVeloraAdapter.Offsets(0, 0, 0),
                swapData: new bytes(0)
            })
        );

        leverageToken.approve(address(leverageRouter), shares);

        // Mock morpho flash loaning the debt required for the redeem
        uint256 flashLoanAmount = requiredDebt;
        deal(address(debtToken), address(leverageRouter), flashLoanAmount);

        vm.prank(address(morpho));
        leverageRouter.onMorphoFlashLoan(
            flashLoanAmount,
            abi.encode(ILeverageRouter.MorphoCallbackData({action: ExternalAction.Redeem, data: redeemWithVeloraData}))
        );
        assertEq(leverageToken.balanceOf(address(this)), 0);
        assertEq(collateralToken.balanceOf(address(this)), requiredCollateral - requiredCollateralForSwap);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_onMorphoFlashLoan_RevertIf_Unauthorized(address caller) public {
        vm.assume(caller != address(morpho));
        vm.expectRevert(ILeverageRouter.Unauthorized.selector);
        leverageRouter.onMorphoFlashLoan(0, "");
    }
}
