// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageRouterBaseTest} from "./LeverageRouterBase.t.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";

import {console2} from "forge-std/console2.sol";

contract WithdrawTest is LeverageRouterBaseTest {
    function testFuzz_withdraw_CollateralSwapWithinMaxCostForFlashLoanRepaymentDebt(
        uint128 requiredCollateral,
        uint128 requiredDebt,
        uint128 equityInCollateralAsset,
        uint256 requiredCollateralForSwap,
        uint128 maxSwapCostInCollateralAsset
    ) public {
        vm.assume(requiredDebt < requiredCollateral);

        uint256 depositShares = 10 ether; // Doesn't matter for this test as the shares received and previewed are mocked
        uint256 withdrawShares = 5 ether; // Doesn't matter for this test as the shares received and previewed are mocked

        equityInCollateralAsset = requiredCollateral - requiredDebt;
        maxSwapCostInCollateralAsset = uint128(bound(maxSwapCostInCollateralAsset, 0, equityInCollateralAsset - 1));

        // Bound the required collateral for the swap to repay the debt flash loan to be within the max swap cost
        requiredCollateralForSwap = uint256(
            bound(
                requiredCollateralForSwap,
                0,
                uint256(requiredCollateral) - equityInCollateralAsset + maxSwapCostInCollateralAsset
            )
        );

        // Mock the swap of the debt asset to the collateral asset
        swapper.mockNextExactOutputSwap(collateralToken, debtToken, requiredCollateralForSwap);

        // Mock the withdraw preview
        leverageManager.setMockPreviewWithdrawData(
            MockLeverageManager.PreviewParams({strategy: strategy, equityInCollateralAsset: equityInCollateralAsset}),
            MockLeverageManager.MockPreviewWithdrawData({
                collateralToRemove: requiredCollateral,
                debtToRepay: requiredDebt,
                shares: withdrawShares,
                sharesFee: 0
            })
        );

        // Mock the LeverageManager withdraw
        leverageManager.setMockWithdrawData(
            MockLeverageManager.WithdrawParams({
                strategy: strategy,
                equityInCollateralAsset: equityInCollateralAsset,
                maxShares: withdrawShares
            }),
            MockLeverageManager.MockWithdrawData({
                collateral: requiredCollateral,
                debt: requiredDebt,
                shares: withdrawShares,
                isExecuted: false
            })
        );

        _deposit(
            equityInCollateralAsset,
            requiredCollateral,
            requiredDebt,
            requiredCollateral - equityInCollateralAsset,
            depositShares
        );

        // Execute the withdraw
        deal(address(debtToken), address(this), requiredDebt);
        debtToken.approve(address(leverageRouter), requiredDebt);
        strategy.approve(address(leverageRouter), withdrawShares);
        leverageRouter.withdraw(
            strategy,
            equityInCollateralAsset,
            withdrawShares,
            maxSwapCostInCollateralAsset,
            // Mock the swap context (doesn't matter for this test as the swap is mocked)
            ISwapAdapter.SwapContext({
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
        );

        // Senders shares are burned
        assertEq(strategy.balanceOf(address(this)), depositShares - withdrawShares);

        // The LeverageRouter has the required debt to repay the flash loan and Morpho is approved to spend it
        assertEq(debtToken.balanceOf(address(leverageRouter)), requiredDebt);
        assertEq(debtToken.allowance(address(leverageRouter), address(morpho)), requiredDebt);

        // Sender receives the remaining collateral (equity)
        assertEq(collateralToken.balanceOf(address(this)), requiredCollateral - requiredCollateralForSwap);
        assertGe(collateralToken.balanceOf(address(this)), equityInCollateralAsset - maxSwapCostInCollateralAsset);
    }

    function testFuzz_withdraw_CollateralSwapMoreThanMaxCostForFlashLoanRepaymentDebt(
        uint128 requiredCollateral,
        uint128 requiredDebt,
        uint128 equityInCollateralAsset,
        uint256 requiredCollateralForSwap,
        uint128 maxSwapCostInCollateralAsset
    ) public {
        vm.assume(requiredDebt < requiredCollateral);

        uint256 shares = 10 ether; // Doesn't matter for this test as the shares received and previewed are mocked

        equityInCollateralAsset = requiredCollateral - requiredDebt;
        maxSwapCostInCollateralAsset = uint128(bound(maxSwapCostInCollateralAsset, 0, equityInCollateralAsset - 1));

        // Bound the required collateral for the swap to repay the debt flash loan to dip deeper into the equity than
        // allowed, per the max swap cost parameter
        requiredCollateralForSwap = uint256(
            bound(
                requiredCollateralForSwap,
                uint256(requiredCollateral) - equityInCollateralAsset + maxSwapCostInCollateralAsset + 1,
                requiredCollateral
            )
        );

        swapper.mockNextExactOutputSwap(collateralToken, debtToken, requiredCollateralForSwap);

        // Mock the withdraw preview
        leverageManager.setMockPreviewWithdrawData(
            MockLeverageManager.PreviewParams({strategy: strategy, equityInCollateralAsset: equityInCollateralAsset}),
            MockLeverageManager.MockPreviewWithdrawData({
                collateralToRemove: requiredCollateral,
                debtToRepay: requiredDebt,
                shares: shares,
                sharesFee: 0
            })
        );

        // Mock the LeverageManager withdraw
        leverageManager.setMockWithdrawData(
            MockLeverageManager.WithdrawParams({
                strategy: strategy,
                equityInCollateralAsset: equityInCollateralAsset,
                maxShares: shares
            }),
            MockLeverageManager.MockWithdrawData({
                collateral: requiredCollateral,
                debt: requiredDebt,
                shares: shares,
                isExecuted: false
            })
        );

        _deposit(
            equityInCollateralAsset,
            requiredCollateral,
            requiredDebt,
            requiredCollateral - equityInCollateralAsset,
            shares
        );

        // Execute the withdraw
        deal(address(debtToken), address(this), requiredDebt);
        debtToken.approve(address(leverageRouter), requiredDebt);
        strategy.approve(address(leverageRouter), shares);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageRouter.MaxSwapCostExceeded.selector,
                equityInCollateralAsset - (requiredCollateral - requiredCollateralForSwap),
                maxSwapCostInCollateralAsset
            )
        );
        leverageRouter.withdraw(
            strategy,
            equityInCollateralAsset,
            shares,
            maxSwapCostInCollateralAsset,
            // Mock the swap context (doesn't matter for this test as the swap is mocked)
            ISwapAdapter.SwapContext({
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
        );
    }

    function _deposit(
        uint256 equityInCollateralAsset,
        uint256 requiredCollateral,
        uint256 requiredDebt,
        uint256 collateralReceivedFromDebtSwap,
        uint256 shares
    ) internal {
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
    }
}
