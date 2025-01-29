// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageRouter} from "src/interfaces/ILeverageRouter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {LendingRouterBaseTest} from "../LendingRouter/LendingRouterBase.t.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";

contract DepositTest is LendingRouterBaseTest {
    function test_deposit_DebtSwapEqualsRequiredFlashLoanRepaymentCollateral() public {
        // Equity to deposit
        uint256 equityInCollateralAsset = 5 ether;

        // Mocked total collateral required to deposit the equity
        uint256 requiredCollateral = 10 ether;
        // Mocked debt required to deposit the equity
        uint256 requiredDebt = 100e6;
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mocked collateral received from the debt swap to be equal to the required flash loan repayment
        uint256 collateralReceivedFromDebtSwap = requiredFlashLoan;
        // User sends only the collateral to cover the equity since the debt swap is equal to the required flash loan repayment
        uint256 collateralFromSender = equityInCollateralAsset;
        // Mocked exchange rate of shares
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset to be equal to the required flash loan repayment
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the deposit preview to match the mocked values
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

        // Mock the deposit to match the mocked values
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
    }

    function test_deposit_RevertIf_DebtSwapLessThanRequiredFlashLoanRepaymentCollateral() public {
        // Equity to deposit
        uint256 equityInCollateralAsset = 5 ether;

        // Mocked total collateral required to deposit the equity
        uint256 requiredCollateral = 10 ether;
        // Mocked debt required to deposit the equity
        uint256 requiredDebt = 100e6;
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mocked collateral received from the debt swap to be less than the required flash loan repayment
        uint256 collateralReceivedFromDebtSwap = requiredFlashLoan - 1;
        // User sends only the collateral to cover the equity
        uint256 collateralFromSender = equityInCollateralAsset;
        // Mocked exchange rate of shares
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset to be equal to the required flash loan repayment
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the deposit preview to match the mocked values
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

        // Mock the deposit to match the mocked values
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

    function test_deposit_DebtSwapLessThanRequiredFlashLoanRepaymentCollateral_SenderSuppliesSufficientCollateral()
        public
    {
        // Equity to deposit
        uint256 equityInCollateralAsset = 5 ether;

        // Mocked total collateral required to deposit the equity
        uint256 requiredCollateral = 10 ether;
        // Mocked debt required to deposit the equity
        uint256 requiredDebt = 100e6;
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mocked collateral received from the debt swap to be less than the required flash loan repayment
        uint256 collateralReceivedFromDebtSwap = requiredFlashLoan - 1;
        // User sends only the collateral to cover the equity plus additional collateral since the debt swap is less than the required flash loan repayment
        uint256 collateralFromSender = equityInCollateralAsset + 1;
        // Mocked exchange rate of shares
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset to be equal to the required flash loan repayment
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the deposit preview to match the mocked values
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

        // Mock the deposit to match the mocked values
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
    }

    function test_deposit_RevertIf_DebtSwapLessThanRequiredFlashLoanRepaymentCollateral_SenderSuppliesInsufficientCollateral(
    ) public {
        // Equity to deposit
        uint256 equityInCollateralAsset = 5 ether;

        // Mocked total collateral required to deposit the equity
        uint256 requiredCollateral = 10 ether;
        // Mocked debt required to deposit the equity
        uint256 requiredDebt = 100e6;
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mocked collateral received from the debt swap to be less than the required flash loan repayment
        uint256 collateralReceivedFromDebtSwap = requiredFlashLoan - 2;
        // User doesn't send enough collateral to help cover the flash loan repayment
        uint256 collateralFromSender = equityInCollateralAsset + 1;
        // Mocked exchange rate of shares
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset to be equal to the required flash loan repayment
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the deposit preview to match the mocked values
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

        // Mock the deposit to match the mocked values
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

    function test_deposit_DebtSwapGreaterThanRequiredFlashLoanRepaymentCollateral() public {
        // Equity to deposit
        uint256 equityInCollateralAsset = 5 ether;

        // Mocked total collateral required to deposit the equity
        uint256 requiredCollateral = 10 ether;
        // Mocked debt required to deposit the equity
        uint256 requiredDebt = 100e6;
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mocked collateral received from the debt swap to be greater than the required flash loan repayment
        uint256 collateralReceivedFromDebtSwap = requiredFlashLoan + 1;
        // User sends only the collateral to cover the equity
        uint256 collateralFromSender = equityInCollateralAsset;
        // Mocked exchange rate of shares
        uint256 shares = 10 ether;

        // Mock the swap of the debt asset to the collateral asset to be equal to the required flash loan repayment
        swapper.mockNextSwap(debtToken, collateralToken, collateralReceivedFromDebtSwap);

        // Mock the deposit preview to match the mocked values
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

        // Mock the deposit to match the mocked values
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

        // Sender receives the surplus collateral asset
        assertEq(collateralToken.balanceOf(address(this)), 1);
    }

    function test_deposit_RevertIf_CollateralFromSenderLessThanEquityInCollateralAsset() public {
        uint256 equityInCollateralAsset = 5 ether;
        uint256 collateralFromSender = equityInCollateralAsset - 1;
        uint256 shares = 10 ether; // Doesn't matter for this test

        vm.expectRevert(ILeverageRouter.InsufficientCollateral.selector);
        leverageRouter.deposit(strategyToken, collateralFromSender, equityInCollateralAsset, shares, "");
    }

    function test_deposit_FlashLoanNotRequired() public {
        // Equity to deposit
        uint256 equityInCollateralAsset = 5 ether;

        // Mocked total collateral required to deposit the equity is equal to the equity being added to the strategy
        uint256 requiredCollateral = 5 ether;
        // Mocked debt required to deposit the equity
        uint256 requiredDebt = 100e6;
        // LeverageRouter will need to flash loan the difference between the required collateral and the equity being added to the strategy, which is 0
        uint256 requiredFlashLoan = 0;
        // User sends only the collateral to cover the equity since no extra collateral is needed
        uint256 collateralFromSender = equityInCollateralAsset;
        // Mocked exchange rate of shares
        uint256 shares = 10 ether;

        // Mock the deposit preview to match the mocked values
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

        // Mock the deposit to match the mocked values
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
    }
}
