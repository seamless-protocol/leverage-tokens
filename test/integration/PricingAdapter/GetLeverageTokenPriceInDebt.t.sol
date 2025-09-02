// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {PricingAdapterTest} from "./PricingAdapter.t.sol";

contract GetLeverageTokenPriceInDebtTest is PricingAdapterTest {
    function testFork_getLeverageTokenPriceInDebt() public {
        uint256 equityInCollateralAsset = 1e18;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        _mint(user, equityInCollateralAsset, collateralToAdd);

        uint256 result = pricingAdapter.getLeverageTokenPriceInDebt(leverageToken);
        assertEq(result, 3392292471);
        assertEq(result, leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInDebtAsset());
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_getLeverageTokenPriceInDebt_CollateralPerShareInDebtAssetLteDebtPerShare(
        uint256 collateralPerShareInDebtAsset,
        uint256 debtPerShare
    ) public {
        collateralPerShareInDebtAsset = uint256(bound(collateralPerShareInDebtAsset, 0, debtPerShare));

        vm.mockCall(
            address(leverageManager),
            abi.encodeWithSelector(ILeverageManager.convertSharesToDebt.selector),
            abi.encode(debtPerShare)
        );

        vm.mockCall(
            address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)),
            abi.encodeWithSelector(ILendingAdapter.convertCollateralToDebtAsset.selector),
            abi.encode(collateralPerShareInDebtAsset)
        );

        uint256 result = pricingAdapter.getLeverageTokenPriceInDebt(leverageToken);
        assertEq(result, 0);
    }

    function testFork_getLeverageTokenPriceInDebt_noShares() public view {
        uint256 result = pricingAdapter.getLeverageTokenPriceInDebt(leverageToken);
        assertEq(result, 0);
    }
}
