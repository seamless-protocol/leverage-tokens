// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {EtherFiLeverageRouterTest} from "./EtherFiLeverageRouter.t.sol";

contract MintTest is EtherFiLeverageRouterTest {
    function testFuzz_Mint(uint256 requiredCollateral, uint256 equityInCollateralAsset) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the mint
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        // Mocked debt required to mint the equity (Doesn't matter for this test due to mocking)
        uint256 requiredDebt = 100e6;

        _mockEtherFiLeverageManagerMint(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        etherFiL2ModeSyncPool.mockSetAmountOut(requiredFlashLoan);

        // Execute the mint
        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(etherFiLeverageRouter), equityInCollateralAsset);
        etherFiLeverageRouter.mint(leverageToken, equityInCollateralAsset, shares);

        // Sender receives the minted shares
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(leverageToken.balanceOf(address(etherFiLeverageRouter)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(etherFiLeverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(etherFiLeverageRouter), address(morpho)), requiredFlashLoan);
    }

    function test_Mint_WithSurplusFromEtherFiLiquidityPool() public {
        uint256 requiredCollateral = 100e18;
        uint256 equityInCollateralAsset = 50e18;
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        // Mocked debt required to mint the equity (Doesn't matter for this test due to mocking)
        uint256 requiredDebt = 100e6;

        _mockEtherFiLeverageManagerMint(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        etherFiL2ModeSyncPool.mockSetAmountOut(requiredFlashLoan + 1); // Surplus of 1 wei of weETH

        // Execute the mint
        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(etherFiLeverageRouter), equityInCollateralAsset);
        etherFiLeverageRouter.mint(leverageToken, equityInCollateralAsset, shares);

        // Sender receives the minted shares
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(leverageToken.balanceOf(address(etherFiLeverageRouter)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(etherFiLeverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(etherFiLeverageRouter), address(morpho)), requiredFlashLoan);

        // The sender receives the 1 wei surplus of weETH
        assertEq(collateralToken.balanceOf(address(this)), 1);
    }
}
