// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {PricingAdapterTest} from "./PricingAdapter.t.sol";

contract GetLeverageTokenPriceInCollateralTest is PricingAdapterTest {
    function testFork_getLeverageTokenPriceInCollateral() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        uint256 result = pricingAdapter.getLeverageTokenPriceInCollateral(leverageToken);
        assertEq(result, 999999999879562786);
        assertEq(result, leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInCollateralAsset());
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_getLeverageTokenPriceInCollateral_CollateralPerShareLteDebtPerShareInCollateralAsset(
        uint256 collateralPerShare,
        uint256 debtPerShareInCollateralAsset
    ) public {
        collateralPerShare = uint256(bound(collateralPerShare, 0, debtPerShareInCollateralAsset));

        vm.mockCall(
            address(leverageManager),
            abi.encodeWithSelector(ILeverageManager.convertSharesToCollateral.selector),
            abi.encode(collateralPerShare)
        );

        vm.mockCall(
            address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)),
            abi.encodeWithSelector(ILendingAdapter.convertDebtToCollateralAsset.selector),
            abi.encode(debtPerShareInCollateralAsset)
        );

        uint256 result = pricingAdapter.getLeverageTokenPriceInCollateral(leverageToken);
        assertEq(result, 0);
    }

    function testFork_getLeverageTokenPriceInCollateral_noShares() public view {
        uint256 result = pricingAdapter.getLeverageTokenPriceInCollateral(leverageToken);
        assertEq(result, 0);
    }
}
