// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";

contract OnMorphoFlashLoanTest is LeverageRouterTest {
    function test_onMorphoFlashLoan_Mint() public {
        uint256 requiredCollateral = 10 ether;
        uint256 equityInCollateralAsset = 5 ether;
        uint256 collateralReceivedFromDebtSwap = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerMint(
            requiredCollateral, equityInCollateralAsset, requiredDebt, collateralReceivedFromDebtSwap, shares
        );

        bytes memory mintData = abi.encode(
            LeverageRouter.MintParams({
                token: leverageToken,
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
                        aerodromePoolFactory: address(0),
                        aerodromeSlipstreamRouter: address(0),
                        uniswapSwapRouter02: address(0),
                        uniswapV2Router02: address(0)
                    })
                })
            })
        );

        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(leverageRouter), equityInCollateralAsset);

        // Also mock morpho flash loaning the additional collateral required for the mint
        uint256 flashLoanAmount = requiredCollateral - equityInCollateralAsset;
        deal(address(collateralToken), address(leverageRouter), flashLoanAmount);

        vm.prank(address(morpho));
        leverageRouter.onMorphoFlashLoan(
            flashLoanAmount,
            abi.encode(LeverageRouter.MorphoCallbackData({action: ExternalAction.Mint, data: mintData}))
        );
        assertEq(leverageToken.balanceOf(address(this)), shares);
    }

    function test_onMorphoFlashLoan_Redeem() public {
        uint256 requiredCollateral = 10 ether;
        uint256 equityInCollateralAsset = 5 ether;
        uint256 collateralReceivedFromDebtSwap = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _mint(equityInCollateralAsset, requiredCollateral, requiredDebt, collateralReceivedFromDebtSwap, shares);

        _mockLeverageManagerRedeem(
            requiredCollateral,
            equityInCollateralAsset,
            requiredDebt,
            requiredCollateral - equityInCollateralAsset,
            shares,
            shares
        );

        bytes memory redeemData = abi.encode(
            LeverageRouter.RedeemParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                shares: shares,
                maxShares: shares,
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
                        aerodromePoolFactory: address(0),
                        aerodromeSlipstreamRouter: address(0),
                        uniswapSwapRouter02: address(0),
                        uniswapV2Router02: address(0)
                    })
                })
            })
        );

        leverageToken.approve(address(leverageRouter), shares);

        // Mock morpho flash loaning the debt required for the redeem
        uint256 flashLoanAmount = requiredDebt;
        deal(address(debtToken), address(leverageRouter), flashLoanAmount);

        vm.prank(address(morpho));
        leverageRouter.onMorphoFlashLoan(
            flashLoanAmount,
            abi.encode(LeverageRouter.MorphoCallbackData({action: ExternalAction.Redeem, data: redeemData}))
        );
        assertEq(leverageToken.balanceOf(address(this)), 0);
        assertEq(collateralToken.balanceOf(address(this)), equityInCollateralAsset);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_onMorphoFlashLoan_RevertIf_Unauthorized(address caller) public {
        vm.assume(caller != address(morpho));
        vm.expectRevert(ILeverageRouter.Unauthorized.selector);
        LeverageRouter(address(leverageRouter)).onMorphoFlashLoan(0, "");
    }
}
