// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageRouterMintBase} from "src/periphery/LeverageRouterMintBase.sol";
import {LeverageRouterMintBaseHarness} from "../harness/LeverageRouterMintBaseHarness.t.sol";
import {LeverageRouterMintBaseTest} from "./LeverageRouterMintBase.t.sol";

contract MintAndRepayMorphoFlashLoanTest is LeverageRouterMintBaseTest {
    function testFuzz_MintAndRepayMorphoFlashLoan(
        uint256 requiredCollateral,
        uint256 equityInCollateralAsset,
        uint256 swapAmountOut,
        bytes memory additionalData
    ) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint128).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the mint
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;

        // Mock the amount of collateral received from the debt swap to be less than required to repay the flash loan
        swapAmountOut = bound(swapAmountOut, 0, requiredFlashLoan);
        leverageRouterMintBase.mock_setNextSwapAmountOut(swapAmountOut);

        // Set the swap slipapge to be the additional collateral required to repay the flash loan
        uint256 maxSwapCostInCollateralAsset = requiredFlashLoan - swapAmountOut;

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        // Mocked debt required to mint the equity (Doesn't matter for this test due to mocking)
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerMint(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        // Deal the sender the equity and approve it to be spent
        deal(address(collateralToken), address(this), equityInCollateralAsset + maxSwapCostInCollateralAsset);
        collateralToken.approve(address(leverageRouterMintBase), equityInCollateralAsset + maxSwapCostInCollateralAsset);

        // Dummy event for checking that the additional data is passed correctly to the _getCollateralFromDebt function
        vm.expectEmit(true, true, true, true);
        emit LeverageRouterMintBaseHarness.AdditionalData(additionalData);

        leverageRouterMintBase.exposed_mintAndRepayMorphoFlashLoan(
            LeverageRouterMintBase.MintParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                maxSwapCostInCollateralAsset: maxSwapCostInCollateralAsset,
                sender: address(this),
                additionalData: additionalData
            }),
            requiredFlashLoan
        );

        // Sender receives the minted shares
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(leverageToken.balanceOf(address(leverageRouterMintBase)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(leverageRouterMintBase)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouterMintBase), address(morpho)), requiredFlashLoan);
    }
}
