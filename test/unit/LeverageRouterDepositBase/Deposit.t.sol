// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageRouterDepositBase} from "src/periphery/LeverageRouterDepositBase.sol";
import {LeverageRouterDepositBaseTest} from "./LeverageRouterDepositBase.t.sol";

contract DepositTest is LeverageRouterDepositBaseTest {
    function testFuzz_Deposit(uint256 requiredCollateral, uint256 equityInCollateralAsset) public {
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

        leverageRouterDepositBase.exposed_deposit(
            LeverageRouterDepositBase.DepositParams({
                token: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares,
                sender: address(this),
                additionalData: ""
            }),
            requiredFlashLoan
        );

        assertEq(leverageToken.balanceOf(address(leverageRouterDepositBase)), shares);
        assertEq(collateralToken.balanceOf(address(leverageRouterDepositBase)), 0);
        assertEq(debtToken.balanceOf(address(leverageRouterDepositBase)), requiredDebt);
    }
}
