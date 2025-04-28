// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageRouterMintBase} from "src/periphery/LeverageRouterMintBase.sol";
import {LeverageRouterMintBaseTest} from "./LeverageRouterMintBase.t.sol";

contract MintTest is LeverageRouterMintBaseTest {
    function testFuzz_Mint(uint256 requiredCollateral, uint256 equityInCollateralAsset) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the mint
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        // Mocked debt required to mint the equity (Doesn't matter for this test due to mocking)
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerMint(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        // Deal the sender the equity and approve it to be spent
        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(leverageRouterMintBase), equityInCollateralAsset);

        leverageRouterMintBase.exposed_mint(
            LeverageRouterMintBase.MintParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                sender: address(this),
                additionalData: ""
            }),
            requiredFlashLoan
        );

        assertEq(leverageToken.balanceOf(address(leverageRouterMintBase)), shares);
        assertEq(collateralToken.balanceOf(address(leverageRouterMintBase)), 0);
        assertEq(debtToken.balanceOf(address(leverageRouterMintBase)), requiredDebt);
    }
}
