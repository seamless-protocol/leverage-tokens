// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageRouterDepositBase} from "src/periphery/LeverageRouterDepositBase.sol";
import {LeverageRouterDepositBaseHarness} from "../harness/LeverageRouterDepositBaseHarness.t.sol";
import {LeverageRouterDepositBaseTest} from "./LeverageRouterDepositBase.t.sol";

contract DepositAndRepayMorphoFlashLoanTest is LeverageRouterDepositBaseTest {
    function testFuzz_DepositAndRepayMorphoFlashLoan(
        uint256 requiredCollateral,
        uint256 equityInCollateralAsset,
        bytes memory additionalData
    ) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the deposit
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        // Mocked debt required to deposit the equity (Doesn't matter for this test due to mocking)
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerDeposit(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        // Deal the sender the equity and approve it to be spent
        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(leverageRouterDepositBase), equityInCollateralAsset);

        // Dummy event for checking that the additional data is passed correctly to the _getCollateralFromDebt function
        vm.expectEmit(true, true, true, true);
        emit LeverageRouterDepositBaseHarness.AdditionalData(additionalData);

        leverageRouterDepositBase.exposed_depositAndRepayMorphoFlashLoan(
            LeverageRouterDepositBase.DepositParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                sender: address(this),
                additionalData: additionalData
            }),
            requiredFlashLoan
        );

        // Sender receives the minted shares
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(leverageToken.balanceOf(address(leverageRouterDepositBase)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(leverageRouterDepositBase)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouterDepositBase), address(morpho)), requiredFlashLoan);
    }
}
