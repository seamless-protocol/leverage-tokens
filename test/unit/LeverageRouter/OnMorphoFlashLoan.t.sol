// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageRouterBaseTest} from "./LeverageRouterBase.t.sol";

contract OnMorphoFlashLoanTest is LeverageRouterBaseTest {
    function test_onMorphoFlashLoan_Deposit() public {
        uint256 requiredCollateral = 10 ether;
        uint256 equityInCollateralAsset = 5 ether;
        uint256 collateralReceivedFromDebtSwap = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerDeposit(
            requiredCollateral, equityInCollateralAsset, requiredDebt, collateralReceivedFromDebtSwap, shares
        );

        bytes memory depositData = abi.encode(
            LeverageRouter.DepositParams({
                strategy: strategy,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                maxSwapCostInCollateralAsset: 0,
                sender: address(this),
                swapContext: ISwapAdapter.SwapContext({
                    path: new address[](0),
                    encodedPath: new bytes(0),
                    fees: new uint24[](0),
                    tickSpacing: new int24[](0),
                    exchange: ISwapAdapter.Exchange.AERODROME,
                    exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                        aerodromeRouter: address(0),
                        aerodromeFactory: address(0),
                        aerodromeSlipstreamRouter: address(0),
                        uniswapRouter02: address(0)
                    })
                })
            })
        );

        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(leverageRouter), equityInCollateralAsset);

        // Also mock morpho flash loaning the additional collateral required for the deposit
        uint256 flashLoanAmount = requiredCollateral - equityInCollateralAsset;
        deal(address(collateralToken), address(leverageRouter), flashLoanAmount);

        vm.prank(address(morpho));
        leverageRouter.onMorphoFlashLoan(
            flashLoanAmount,
            abi.encode(LeverageRouter.MorphoCallbackData({action: ExternalAction.Deposit, data: depositData}))
        );
        assertEq(strategy.balanceOf(address(this)), shares);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_onMorphoFlashLoan_RevertIf_Unauthorized(address caller) public {
        vm.assume(caller != address(morpho));
        vm.expectRevert(ILeverageRouter.Unauthorized.selector);
        LeverageRouter(address(leverageRouter)).onMorphoFlashLoan(0, "");
    }
}
