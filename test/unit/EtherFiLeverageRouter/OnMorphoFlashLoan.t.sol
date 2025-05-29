// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {EtherFiLeverageRouter} from "src/periphery/EtherFiLeverageRouter.sol";
import {LeverageRouterMintBase} from "src/periphery/LeverageRouterMintBase.sol";
import {IEtherFiLeverageRouter} from "src/interfaces/periphery/IEtherFiLeverageRouter.sol";
import {ILeverageRouterBase} from "src/interfaces/periphery/ILeverageRouterBase.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {EtherFiLeverageRouterTest} from "./EtherFiLeverageRouter.t.sol";

contract OnMorphoFlashLoanTest is EtherFiLeverageRouterTest {
    function test_onMorphoFlashLoan_Mint() public {
        uint256 requiredCollateral = 10 ether;
        uint256 equityInCollateralAsset = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _mockEtherFiLeverageManagerMint(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        bytes memory mintData = abi.encode(
            LeverageRouterMintBase.MintParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                maxSwapCostInCollateralAsset: 0,
                sender: address(this),
                additionalData: ""
            })
        );

        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(etherFiLeverageRouter), equityInCollateralAsset);

        // Also mock morpho flash loaning the additional collateral required for the mint
        uint256 flashLoanAmount = requiredCollateral - equityInCollateralAsset;
        deal(address(collateralToken), address(etherFiLeverageRouter), flashLoanAmount);

        etherFiL2ModeSyncPool.mockSetAmountOut(flashLoanAmount);

        vm.prank(address(morpho));
        etherFiLeverageRouter.onMorphoFlashLoan(flashLoanAmount, mintData);
        assertEq(leverageToken.balanceOf(address(this)), shares);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_onMorphoFlashLoan_RevertIf_Unauthorized(address caller) public {
        vm.assume(caller != address(morpho));
        vm.expectRevert(ILeverageRouterBase.Unauthorized.selector);
        EtherFiLeverageRouter(payable(address(etherFiLeverageRouter))).onMorphoFlashLoan(0, "");
    }
}
