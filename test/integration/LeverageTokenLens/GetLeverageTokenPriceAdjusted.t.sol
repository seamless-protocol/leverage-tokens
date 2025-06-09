// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {LeverageTokenLensTest} from "./LeverageTokenLens.t.sol";

contract GetLeverageTokenPriceAdjustedTest is LeverageTokenLensTest {
    function test_getLeverageTokenPriceAdjusted_baseAssetIsCollateralAsset() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        int256 result = leverageTokenLens.getLeverageTokenPriceAdjusted(leverageToken, WETH_USD_ORACLE, false);
        assertEq(result, 339238999959); // 3,392.38999959 USD
    }

    function test_getLeverageTokenPriceAdjusted_baseAssetIsDebtAsset() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        int256 result = leverageTokenLens.getLeverageTokenPriceAdjusted(leverageToken, USDC_USD_ORACLE, true);
        assertEq(result, 339238999940); // 3392.38999940 / 1e8 USD
    }
}
