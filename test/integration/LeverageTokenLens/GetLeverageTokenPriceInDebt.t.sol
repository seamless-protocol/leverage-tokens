// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {LeverageTokenLensTest} from "./LeverageTokenLens.t.sol";

contract GetLeverageTokenPriceInDebtTest is LeverageTokenLensTest {
    function test_getLeverageTokenPriceInDebt() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        uint256 result = leverageTokenLens.getLeverageTokenPriceInDebt(leverageToken);
        assertEq(result, 3392292471);
        assertEq(result, leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInDebtAsset());
    }

    function test_getLeverageTokenPriceInDebt_noShares() public view {
        uint256 result = leverageTokenLens.getLeverageTokenPriceInDebt(leverageToken);
        assertEq(result, 0);
    }
}
