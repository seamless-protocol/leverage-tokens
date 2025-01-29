// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageRouter} from "src/interfaces/ILeverageRouter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {LendingRouterBaseTest} from "../LendingRouter/LendingRouterBase.t.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";

contract DepositTest is LendingRouterBaseTest {
    function testFuzz_deposit_DebtSwapGteRequiredFlashLoanRepaymentCollateral(
        uint256 equityInCollateralAsset,
        uint256 requiredCollateral,
        uint256 collateralReceivedFromDebtSwap,
        uint256 collateralFromSender
    ) public {
        // Mock total collateral required to deposit the equity to be greater than the equity being added to the strategy so that
        // a flash loan is required. We bound the max value to max uint136 to avoid a revert during deposit due to overflow when
        // adding the collateral from the sender to the flash loaned collateral (avoiding balanceOf collateral on the LeverageRouter
        // being greater than type(uint256).max)
        equityInCollateralAsset = bound(equityInCollateralAsset, 1, type(uint136).max - 1);
        requiredCollateral = bound(requiredCollateral, uint256(equityInCollateralAsset) + 1, type(uint136).max);

        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mock collateral received from the debt swap to be >= the required flash loan repayment
        collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, requiredFlashLoan, type(uint136).max);
        // User sends at least the equity for the deposit
        collateralFromSender =
            bound(collateralFromSender, equityInCollateralAsset, type(uint256).max - collateralReceivedFromDebtSwap);

        // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;
        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the LeverageManager deposit preview
        leverageManager.setMockPreviewDepositData(
            MockLeverageManager.PreviewDepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset
            }),
            MockLeverageManager.MockPreviewDepositData({
                shares: shares,
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt
            })
        );

        // Mock the LeverageManager deposit
        leverageManager.setMockDepositData(
            MockLeverageManager.DepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares
            }),
            MockLeverageManager.MockDepositData({
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt,
                shares: shares,
                isExecuted: false
            })
        );

        // Execute the deposit
        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);
        uint256 sharesReceived =
            leverageRouter.deposit(strategyToken, collateralFromSender, equityInCollateralAsset, shares, "");

        // LeverageRouter.deposit returns the shares that LeverageManager.deposit returns
        assertEq(sharesReceived, shares);

        // Sender receives the minted shares
        assertEq(strategyToken.balanceOf(address(this)), shares);
        assertEq(strategyToken.balanceOf(address(leverageRouter)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

        // Sender receives any surplus collateral asset leftover after the flash loan is repaid
        assertEq(
            collateralToken.balanceOf(address(this)),
            (collateralReceivedFromDebtSwap - requiredFlashLoan) + (collateralFromSender - equityInCollateralAsset)
        );
    }

    function testFuzz_deposit_DebtSwapLessThanRequiredFlashLoanRepaymentCollateral_SenderSuppliesSufficientCollateral(
        uint256 equityInCollateralAsset,
        uint256 requiredCollateral,
        uint256 collateralReceivedFromDebtSwap,
        uint256 collateralFromSender
    ) public {
        // Mock total collateral required to deposit the equity to be greater than the equity being added to the strategy so that
        // a flash loan is required. We bound the max value to max uint136 to avoid a revert during deposit due to overflow when
        // adding the collateral from the sender to the flash loaned collateral (avoiding balanceOf collateral on the LeverageRouter
        // being greater than type(uint256).max)
        equityInCollateralAsset = bound(equityInCollateralAsset, 1, type(uint136).max - 1);
        requiredCollateral = bound(requiredCollateral, equityInCollateralAsset + 1, type(uint136).max);

        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mock collateral received from the debt swap to be less than the required flash loan repayment
        collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, 0, requiredFlashLoan - 1);
        // The delta between the required flash loan repayment and the collateral received from the debt swap is the additional collateral
        // required to cover the flash loan repayment
        uint256 additionalCollateralRequiredForFlashLoanRepay = requiredFlashLoan - collateralReceivedFromDebtSwap;
        // User sends at minimum an amount of collateral to cover the equity plus additional collateral to help with flash loan repayment
        collateralFromSender = bound(
            collateralFromSender,
            equityInCollateralAsset + additionalCollateralRequiredForFlashLoanRepay,
            type(uint256).max - requiredCollateral
        );

        // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;
        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the LeverageManager deposit preview
        leverageManager.setMockPreviewDepositData(
            MockLeverageManager.PreviewDepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset
            }),
            MockLeverageManager.MockPreviewDepositData({
                shares: shares,
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt
            })
        );

        // Mock the LeverageManager deposit
        leverageManager.setMockDepositData(
            MockLeverageManager.DepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares
            }),
            MockLeverageManager.MockDepositData({
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt,
                shares: shares,
                isExecuted: false
            })
        );

        // Execute the deposit
        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);
        uint256 sharesReceived =
            leverageRouter.deposit(strategyToken, collateralFromSender, equityInCollateralAsset, shares, "");

        // LeverageRouter.deposit returns the shares that LeverageManager.deposit returns
        assertEq(sharesReceived, shares);

        // Sender receives the minted shares
        assertEq(strategyToken.balanceOf(address(this)), shares);
        assertEq(strategyToken.balanceOf(address(leverageRouter)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

        // Sender receives any surplus collateral asset leftover after the flash loan is repaid
        assertEq(
            collateralToken.balanceOf(address(this)),
            collateralFromSender - (requiredCollateral - collateralReceivedFromDebtSwap)
        );
    }

    function testFuzz_deposit_RevertIf_InsufficientCollateralToRepayFlashLoan(
        uint128 equityInCollateralAsset,
        uint256 requiredCollateral,
        uint256 collateralReceivedFromDebtSwap,
        uint256 collateralFromSender
    ) public {
        // Mock total collateral required to deposit the equity to be greater than the equity being added to the strategy so that
        // a flash loan is required. We bound the max value to max uint136 to avoid a revert during deposit due to overflow when
        // adding the collateral from the sender to the flash loaned collateral (avoiding balanceOf collateral on the LeverageRouter
        // being greater than type(uint256).max)
        requiredCollateral = bound(requiredCollateral, uint256(equityInCollateralAsset) + 1, type(uint136).max);
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mock collateral received from the debt swap to be less than the required flash loan repayment
        collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, 0, requiredFlashLoan - 1);
        // The delta between the required flash loan repayment and the collateral received from the debt swap is the additional collateral
        // required to cover the flash loan
        uint256 additionalCollateralRequiredForFlashLoan = requiredFlashLoan - collateralReceivedFromDebtSwap;
        // We bound the value of the collateral from the sender to be at least the equity but less than the required amount to assist with
        // the flash loan repayment
        collateralFromSender = bound(
            collateralFromSender,
            equityInCollateralAsset,
            equityInCollateralAsset + additionalCollateralRequiredForFlashLoan - 1
        );

        // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;
        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the LeverageManager deposit preview
        leverageManager.setMockPreviewDepositData(
            MockLeverageManager.PreviewDepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset
            }),
            MockLeverageManager.MockPreviewDepositData({
                shares: shares,
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt
            })
        );

        // Mock the LeverageManager deposit
        leverageManager.setMockDepositData(
            MockLeverageManager.DepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares
            }),
            MockLeverageManager.MockDepositData({
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt,
                shares: shares,
                isExecuted: false
            })
        );

        // Execute the deposit
        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);
        vm.expectRevert(ILeverageRouter.InsufficientCollateralToRepayFlashLoan.selector);
        leverageRouter.deposit(strategyToken, collateralFromSender, equityInCollateralAsset, shares, "");
    }

    function testFuzz_deposit_FlashLoanNotRequired(
        uint256 equityInCollateralAsset,
        uint256 requiredCollateral,
        uint256 collateralFromSender
    ) public {
        equityInCollateralAsset = bound(equityInCollateralAsset, 1, type(uint256).max);

        // Mock total collateral required to deposit the equity to be less than or equal to the equity being added to the strateg so that
        // a flash loan is not required
        requiredCollateral = bound(requiredCollateral, 0, equityInCollateralAsset);
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy, which is 0
        // when the required collateral is less than or equal to the equity being added to the strategy
        uint256 requiredFlashLoan = 0;
        // User sends some amount of collateral, which is at least equal to the equity being added to the strategy
        collateralFromSender = bound(collateralFromSender, equityInCollateralAsset, type(uint256).max);

        // Mocked debt required to deposit the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;
        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;

        // Mock the LeverageManager deposit preview
        leverageManager.setMockPreviewDepositData(
            MockLeverageManager.PreviewDepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset
            }),
            MockLeverageManager.MockPreviewDepositData({
                shares: shares,
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt
            })
        );

        // Mock the LeverageManager deposit
        leverageManager.setMockDepositData(
            MockLeverageManager.DepositParams({
                strategy: strategyToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares
            }),
            MockLeverageManager.MockDepositData({
                requiredCollateral: requiredCollateral,
                requiredDebt: requiredDebt,
                shares: shares,
                isExecuted: false
            })
        );

        // Execute the deposit
        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);
        uint256 sharesReceived =
            leverageRouter.deposit(strategyToken, collateralFromSender, equityInCollateralAsset, shares, "");

        // LeverageRouter.deposit returns the shares that LeverageManager.deposit returns
        assertEq(sharesReceived, shares);

        // Sender receives the minted shares
        assertEq(strategyToken.balanceOf(address(this)), shares);
        assertEq(strategyToken.balanceOf(address(leverageRouter)), 0);

        // The LeverageRouter has zero balance of collateral since no flash loan was required
        assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

        // Sender receives any surplus collateral asset leftover after the deposit of equity into the strategy
        assertEq(collateralToken.balanceOf(address(this)), collateralFromSender - requiredCollateral);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_CollateralFromSenderLessThanEquityInCollateralAsset(
        uint256 equityInCollateralAsset,
        uint256 collateralFromSender
    ) public {
        equityInCollateralAsset = bound(equityInCollateralAsset, 1, type(uint256).max - 1);
        collateralFromSender = bound(collateralFromSender, 0, equityInCollateralAsset - 1);
        uint256 shares = 10 ether; // Doesn't matter for this test

        vm.expectRevert(ILeverageRouter.InsufficientCollateral.selector);
        leverageRouter.deposit(strategyToken, collateralFromSender, equityInCollateralAsset, shares, "");
    }
}
