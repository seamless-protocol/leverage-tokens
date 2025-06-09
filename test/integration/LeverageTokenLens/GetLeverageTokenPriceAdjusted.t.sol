// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {LeverageTokenLensTest} from "./LeverageTokenLens.t.sol";

contract GetLeverageTokenPriceAdjustedTest is LeverageTokenLensTest {
    function testFork_getLeverageTokenPriceAdjusted_baseAssetIsCollateralAsset() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        int256 oraclePrice = WETH_USD_ORACLE.latestAnswer();
        assertEq(oraclePrice, 339239000000); // Price in this block for 1 WETH is 3392.39000000 USD

        uint256 leverageTokenEquity =
            leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInCollateralAsset();
        assertEq(leverageTokenEquity, 999999999879562786); // The amount of equity in collateral asset is 999999999879562786 (~0.99 WETH)

        uint256 expectedPrice = uint256(oraclePrice) * leverageTokenEquity / 1e18;
        assertEq(expectedPrice, 339238999959);

        int256 result = leverageTokenLens.getLeverageTokenPriceAdjusted(leverageToken, WETH_USD_ORACLE, false);
        assertEq(result, 339238999959); // 3,392.38999959 USD
    }

    function testFork_getLeverageTokenPriceAdjusted_baseAssetIsDebtAsset() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        int256 result = leverageTokenLens.getLeverageTokenPriceAdjusted(leverageToken, USDC_USD_ORACLE, true);
        assertEq(result, 339238999940); // 3392.38999940 / 1e8 USD
    }
}
