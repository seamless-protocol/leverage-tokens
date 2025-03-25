// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerBaseTest} from "./DutchAuctionRebalancerBase.t.sol";

contract ExecuteRebalanceUpTest is DutchAuctionRebalancerBaseTest {
    function testFuzz_executeRebalanceUp(uint256 collateral, uint256 debt) public {
        // Fund the caller with required collateral and approve
        deal(address(collateralToken), address(leverageManager), collateral);
        deal(address(debtToken), address(this), debt);

        // Record balances before
        uint256 callerCollateralBefore = collateralToken.balanceOf(address(this));
        uint256 callerDebtBefore = debtToken.balanceOf(address(this));

        // Execute rebalance up
        debtToken.approve(address(auctionRebalancer), debt);
        auctionRebalancer.exposed_executeRebalanceUp(leverageToken, collateral, debt);

        // Verify caller's token balances changed correctly
        assertEq(collateralToken.balanceOf(address(this)), callerCollateralBefore + collateral);
        assertEq(debtToken.balanceOf(address(this)), callerDebtBefore - debt);

        // Verify tokens moved to/from leverage manager
        assertEq(collateralToken.balanceOf(address(leverageManager)), 0);
        assertEq(debtToken.balanceOf(address(leverageManager)), debt);
    }
}
