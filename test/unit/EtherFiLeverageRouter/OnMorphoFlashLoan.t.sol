// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {EtherFiLeverageRouter} from "src/periphery/EtherFiLeverageRouter.sol";
import {LeverageRouterDepositBase} from "src/periphery/LeverageRouterDepositBase.sol";
import {IEtherFiLeverageRouter} from "src/interfaces/periphery/IEtherFiLeverageRouter.sol";
import {ILeverageRouterBase} from "src/interfaces/periphery/ILeverageRouterBase.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {EtherFiLeverageRouterTest} from "./EtherFiLeverageRouter.t.sol";

contract OnMorphoFlashLoanTest is EtherFiLeverageRouterTest {
    function test_onMorphoFlashLoan_Deposit() public {
        uint256 requiredCollateral = 10 ether;
        uint256 equityInCollateralAsset = 5 ether;
        uint256 shares = 10 ether;
        uint256 requiredDebt = 100e6;

        _mockEtherFiLeverageManagerDeposit(requiredCollateral, equityInCollateralAsset, requiredDebt, shares);

        bytes memory depositData = abi.encode(
            LeverageRouterDepositBase.DepositParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                sender: address(this),
                additionalData: ""
            })
        );

        deal(address(collateralToken), address(this), equityInCollateralAsset);
        collateralToken.approve(address(etherFiLeverageRouter), equityInCollateralAsset);

        // Also mock morpho flash loaning the additional collateral required for the deposit
        uint256 flashLoanAmount = requiredCollateral - equityInCollateralAsset;
        deal(address(collateralToken), address(etherFiLeverageRouter), flashLoanAmount);

        etherFiL2ModeSyncPool.mockSetAmountOut(flashLoanAmount);

        vm.prank(address(morpho));
        etherFiLeverageRouter.onMorphoFlashLoan(flashLoanAmount, depositData);
        assertEq(leverageToken.balanceOf(address(this)), shares);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_onMorphoFlashLoan_RevertIf_Unauthorized(address caller) public {
        vm.assume(caller != address(morpho));
        vm.expectRevert(ILeverageRouterBase.Unauthorized.selector);
        EtherFiLeverageRouter(payable(address(etherFiLeverageRouter))).onMorphoFlashLoan(0, "");
    }
}
