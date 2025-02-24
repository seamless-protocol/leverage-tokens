// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.26;

// // Internal imports
// import {IFeeManager} from "src/interfaces/IFeeManager.sol";
// import {ILeverageRouter} from "src/interfaces/ILeverageRouter.sol";
// import {IStrategy} from "src/interfaces/IStrategy.sol";
// import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
// import {LeverageRouterBaseTest} from "./LeverageRouterBase.t.sol";
// import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
// import {StrategyState} from "src/types/DataTypes.sol";

// contract DepositTest is LeverageRouterBaseTest {
//     function testFuzz_deposit_DebtSwapLessThanRequiredFlashLoanRepaymentCollateral_SenderSuppliesSufficientCollateral(
//         uint256 requiredCollateral,
//         uint256 collateralReceivedFromDebtSwap,
//         uint256 collateralFromSender
//     ) public {
//         requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);

//         // LeverageRouter will flash loan the required collateral
//         uint256 requiredFlashLoan = requiredCollateral;
//         // Mock collateral received from the debt swap to be less than the required flash loan repayment
//         collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, 0, requiredFlashLoan - 1);
//         // The delta between the required flash loan repayment and the collateral received from the debt swap is the additional collateral
//         // required to cover the flash loan repayment
//         uint256 additionalCollateralRequiredForFlashLoanRepay = requiredFlashLoan - collateralReceivedFromDebtSwap;
//         // User approves at minimum an amount of collateral to cover the additional collateral to help with flash loan repayment. We bound the max
//         // to avoid overflows when adding the collateral from the sender to the collateral from the debt swap
//         collateralFromSender = bound(
//             collateralFromSender,
//             additionalCollateralRequiredForFlashLoanRepay,
//             type(uint256).max - collateralReceivedFromDebtSwap
//         );

//         // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
//         uint256 requiredDebt = 100e6;
//         // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
//         uint256 shares = 10 ether;

//         // Mock the swap of the debt asset to the collateral asset
//         swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

//         // Mock the deposit into leverage manager
//         leverageManager.setMockDepositData(
//             MockLeverageManager.DepositParams({
//                 strategy: strategyToken,
//                 collateral: requiredCollateral,
//                 debt: requiredDebt,
//                 minShares: shares
//             }),
//             MockLeverageManager.MockDepositData({shares: shares, isExecuted: false})
//         );

//         // Execute the deposit
//         deal(address(collateralToken), address(this), collateralFromSender);
//         collateralToken.approve(address(leverageRouter), additionalCollateralRequiredForFlashLoanRepay);
//         leverageRouter.deposit(
//             strategyToken,
//             requiredCollateral,
//             requiredDebt,
//             shares,
//             additionalCollateralRequiredForFlashLoanRepay,
//             // Mock the swap context (doesn't matter for this test as the swap is mocked)
//             ISwapAdapter.SwapContext({
//                 route: new address[](0),
//                 tickSpacing: new int24[](0),
//                 exchange: ISwapAdapter.Exchange.Aerodrome
//             })
//         );

//         // Sender receives the minted shares
//         assertEq(strategyToken.balanceOf(address(this)), shares);
//         assertEq(strategyToken.balanceOf(address(leverageRouter)), 0);

//         // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
//         assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
//         assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

//         // Sender's collateral is used to help repay the flash loan
//         assertEq(
//             collateralToken.balanceOf(address(this)),
//             collateralFromSender - additionalCollateralRequiredForFlashLoanRepay
//         );
//     }

//     function testFuzz_deposit_DebtSwapGteRequiredFlashLoanRepaymentCollateral(
//         uint256 requiredCollateral,
//         uint256 collateralReceivedFromDebtSwap
//     ) public {
//         requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);

//         // LeverageRouter will flash loan the required collateral
//         uint256 requiredFlashLoan = requiredCollateral;
//         // Mock collateral received from the debt swap to be >= the required flash loan repayment
//         collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, requiredFlashLoan, type(uint256).max);
//         // Sender does not need to send any additional collateral to help repay the flash loan, as the debt swap results in enough collateral
//         // to repay the flash loan
//         uint256 requiredCollateralFromSender = 0;

//         // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
//         uint256 requiredDebt = 100e6;
//         // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
//         uint256 shares = 10 ether;

//         // Mock the swap of the debt asset to the collateral asset
//         swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

//         // Mock the deposit into leverage manager
//         leverageManager.setMockDepositData(
//             MockLeverageManager.DepositParams({
//                 strategy: strategyToken,
//                 collateral: requiredCollateral,
//                 debt: requiredDebt,
//                 minShares: shares
//             }),
//             MockLeverageManager.MockDepositData({shares: shares, isExecuted: false})
//         );

//         // Execute the deposit
//         collateralToken.approve(address(leverageRouter), requiredCollateralFromSender);
//         leverageRouter.deposit(
//             strategyToken,
//             requiredCollateral,
//             requiredDebt,
//             shares,
//             requiredCollateralFromSender,
//             // Mock the swap context (doesn't matter for this test as the swap is mocked)
//             ISwapAdapter.SwapContext({
//                 route: new address[](0),
//                 tickSpacing: new int24[](0),
//                 exchange: ISwapAdapter.Exchange.Aerodrome
//             })
//         );

//         // Sender receives the minted shares
//         assertEq(strategyToken.balanceOf(address(this)), shares);
//         assertEq(strategyToken.balanceOf(address(leverageRouter)), 0);

//         // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
//         assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
//         assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

//         // Sender receives any surplus collateral asset leftover after the flash loan is repaid, due to the debt swap being favorable
//         assertEq(
//             collateralToken.balanceOf(address(this)),
//             collateralReceivedFromDebtSwap > requiredFlashLoan ? collateralReceivedFromDebtSwap - requiredFlashLoan : 0
//         );
//     }

//     function testFuzz_deposit_RevertIf_InsufficientCollateralToRepayFlashLoan(
//         uint256 requiredCollateral,
//         uint256 collateralReceivedFromDebtSwap,
//         uint256 collateralFromSender
//     ) public {
//         requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);

//         // LeverageRouter will flash loan the required collateral
//         uint256 requiredFlashLoan = requiredCollateral;
//         // Mock collateral received from the debt swap to be less than the required flash loan repayment
//         collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, 0, requiredFlashLoan - 1);
//         // The delta between the required flash loan repayment and the collateral received from the debt swap is the additional collateral
//         // required to cover the flash loan
//         uint256 additionalCollateralRequiredForFlashLoan = requiredFlashLoan - collateralReceivedFromDebtSwap;
//         // User does not approve enough collateral to cover the additional collateral to help with flash loan repayment. We bound the max
//         // to avoid overflows when adding the collateral from the sender to the collateral from the debt swap
//         collateralFromSender = bound(collateralFromSender, 0, additionalCollateralRequiredForFlashLoan - 1);

//         // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
//         uint256 requiredDebt = 100e6;
//         // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
//         uint256 shares = 10 ether;

//         // Mock the swap of the debt asset to the collateral asset
//         swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

//         // Mock the LeverageManager deposit
//         leverageManager.setMockDepositData(
//             MockLeverageManager.DepositParams({
//                 strategy: strategyToken,
//                 collateral: requiredCollateral,
//                 debt: requiredDebt,
//                 minShares: shares
//             }),
//             MockLeverageManager.MockDepositData({shares: shares, isExecuted: false})
//         );

//         // Execute the deposit
//         deal(address(collateralToken), address(this), collateralFromSender);
//         collateralToken.approve(address(leverageRouter), collateralFromSender);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 ILeverageRouter.SlippageTooHigh.selector, collateralFromSender, additionalCollateralRequiredForFlashLoan
//             )
//         );
//         leverageRouter.deposit(
//             strategyToken,
//             requiredCollateral,
//             requiredDebt,
//             shares,
//             collateralFromSender,
//             // Mock the swap context (doesn't matter for this test as the swap is mocked)
//             ISwapAdapter.SwapContext({
//                 route: new address[](0),
//                 tickSpacing: new int24[](0),
//                 exchange: ISwapAdapter.Exchange.Aerodrome
//             })
//         );
//     }
// }
