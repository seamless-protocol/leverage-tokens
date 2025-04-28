// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {LeverageManagerTest} from "./LeverageManager.t.sol";
import {ActionData, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";

contract LeverageManagerWithdrawTest is LeverageManagerTest {
    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_withdraw_NoFee() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _mint(user, equityInCollateralAsset, collateralToAdd);

        LeverageTokenState memory stateBefore = getLeverageTokenState();
        assertEq(stateBefore.collateralRatio, 1999999999970521409); // ~2x CR

        uint256 equityToWithdraw = 5 ether;
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        LeverageTokenState memory stateAfter = getLeverageTokenState();

        // Ensure that collateral ratio is the same (with some rounding error)
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertEq(stateAfter.collateralRatio, 2000000000058957180);
        assertEq(stateAfter.debt, stateBefore.debt - previewData.debt);

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_ZeroAmount() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _mint(user, equityInCollateralAsset, collateralToAdd);

        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, 0);
        _withdraw(user, 0, previewData.debt);

        assertEq(previewData.collateral, 0);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
    }

    function testFork_withdraw_FullWithdraw() public {
        (,, address oracle,,) = morphoLendingAdapter.marketParams();
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(4000e24));

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 shares = _mint(user, equityInCollateralAsset, collateralToAdd);

        uint256 sharesValue = _convertToAssets(shares);
        uint256 debtToRepay = leverageManager.previewWithdraw(leverageToken, sharesValue).debt;
        _withdraw(user, sharesValue, debtToRepay);

        // Validate that all shares are burned
        assertEq(leverageToken.totalSupply(), 0);

        // Validate that almost all collateral is withdrawn, we round down collateral to withdraw so dust can be left
        assertGe(morphoLendingAdapter.getCollateral(), 0);
        assertLe(morphoLendingAdapter.getCollateral(), 2);

        // Validate that entire debt is repaid successfully
        assertEq(morphoLendingAdapter.getDebt(), 0);
    }

    function testFork_withdraw_MockPrice() public {
        // Mock ETH price to be 4000 USDC
        (,, address oracle,,) = morphoLendingAdapter.marketParams();
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(4000e24));

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _mint(user, equityInCollateralAsset, collateralToAdd);

        LeverageTokenState memory stateBefore = getLeverageTokenState();
        assertEq(stateBefore.collateralRatio, 1999999999950000000); // ~2x CR

        uint256 equityInCollateralAssetBeforeWithdraw = morphoLendingAdapter.getEquityInCollateralAsset();
        assertEq(equityInCollateralAssetBeforeWithdraw, 9999999999750000000);

        uint256 equityToWithdraw = equityInCollateralAssetBeforeWithdraw / 2;
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        LeverageTokenState memory stateAfter = getLeverageTokenState();
        uint256 equityInCollateralAssetAfterWithdraw = morphoLendingAdapter.getEquityInCollateralAsset();

        // Ensure that collateral ratio is the same
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertEq(stateAfter.collateralRatio, 2000000000000000000);

        // Ensure that after withdraw debt and collateral is 50% of what was initially after mint
        assertEq(stateAfter.debt, 20000_000000); // 2000 USDC
        assertEq(equityInCollateralAssetAfterWithdraw, equityInCollateralAsset / 2);

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_PriceChangedBetweenWithdraws_CollateralRatioDoesNotChange() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _mint(user, equityInCollateralAsset, collateralToAdd);

        // Mock ETH price to be 4000 USDC
        (,, address oracle,,) = morphoLendingAdapter.marketParams();
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(4000e24));

        LeverageTokenState memory stateBefore = getLeverageTokenState();
        assertEq(stateBefore.collateralRatio, 2358287225224640032); // ~2x CR

        uint256 equityToWithdraw = 5 ether;
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        LeverageTokenState memory stateAfter = getLeverageTokenState();

        // Ensure that collateral ratio is the same, with some rounding error
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertEq(stateAfter.collateralRatio, 2358287225265780836);

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_fullWithdrawComparedToPartialWithdrawals() public {
        // Mint some assets initially
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 sharesAfterMint = _mint(user, equityInCollateralAsset, collateralToAdd);

        // Withdraw everything
        uint256 sharesValueAfterMint = _convertToAssets(sharesAfterMint);
        ActionData memory previewDataAfterMint = leverageManager.previewWithdraw(leverageToken, sharesValueAfterMint);
        _withdraw(user, sharesValueAfterMint, previewDataAfterMint.debt);

        // Mint again to create the same scenario
        sharesAfterMint = _mint(user, equityInCollateralAsset, collateralToAdd);

        // Withdraw half of it
        uint256 equityToWithdraw = equityInCollateralAsset / 2;
        ActionData memory previewDataFirstTime = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewDataFirstTime.debt);

        // Withdraw the rest
        equityToWithdraw = _convertToAssets(leverageToken.balanceOf(user));
        ActionData memory previewDataSecondTime = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewDataSecondTime.debt);

        // Validate that in both cases we get the same amount of collateral and debt
        assertEq(previewDataFirstTime.collateral + previewDataSecondTime.collateral, previewDataAfterMint.collateral);
        assertEq(previewDataFirstTime.debt + previewDataSecondTime.debt, previewDataAfterMint.debt);

        // Validate that collateral token is properly transferred to user
        assertEq(WETH.balanceOf(user), previewDataFirstTime.collateral + previewDataSecondTime.collateral);
        assertLe(previewDataAfterMint.collateral, 2 * equityInCollateralAsset);
    }

    function testFork_withdraw_withFee() public {
        uint256 treasuryActionFee = 10_00; // 10%
        leverageManager.setTreasuryActionFee(ExternalAction.Withdraw, treasuryActionFee); // 10%

        uint128 managementFee = 10_00; // 10%
        leverageManager.setManagementFee(managementFee);

        uint256 tokenActionFee = 10_00; // 10%
        leverageToken =
            _createNewLeverageToken(BASE_RATIO, 2 * BASE_RATIO, 3 * BASE_RATIO, tokenActionFee, tokenActionFee);
        morphoLendingAdapter =
            MorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)));

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _mint(user, equityInCollateralAsset, collateralToAdd);

        // 10% of equity goes to share dilution (token action fee), so 9 ether shares are minted instead of 10 ether
        assertEq(leverageToken.balanceOf(user), 9 ether);
        assertEq(leverageToken.totalSupply(), 9 ether);

        uint256 equityInCollateralAssetAfterMint = morphoLendingAdapter.getEquityInCollateralAsset();

        // Withdraw 50% of equity
        uint256 equityToWithdraw = equityInCollateralAssetAfterMint / 2;
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        // Half of the equity is withdrawn, so half of the total supply is burned + an additional 10% for the token action fee
        // (9/2)*1.1 = 4.95 burned, 4.05 remaining
        assertEq(leverageToken.totalSupply(), 9 ether - 4.95 ether);
        // 10% of the total shares burned are minted to the treasury to cover the treasury fee. 4.95 * 0.1 = 0.495
        assertEq(leverageToken.balanceOf(treasury), 0.495 ether);
        // The user's shares are decreased by the burned shares including token and treasury fees. 9 - (4.5 * 1.1 * 1.1) = 9 - 5.445 = 3.555
        assertEq(leverageToken.balanceOf(user), 3.555 ether);

        assertEq(WETH.balanceOf(user), previewData.collateral); // User receives the collateral asset

        // One year passes
        skip(SECONDS_ONE_YEAR);

        // To withdraw the same amount of equity we need to burn more shares because of the share dilution from the
        // management fee and morpho borrow interest
        previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        assertEq(previewData.shares, 5.460965008456074474 ether);

        uint256 userTotalShareValue = Math.mulDiv(
            // An additional 10% of shares are required to be burned from the user to cover the treasury action fee,
            // and an additional 10% of shares are required to be burned from the user to cover the token action fee
            // 1.1 * 1.1 = 1.21
            Math.mulDiv(leverageToken.balanceOf(user), 1e18, 1.21e18, Math.Rounding.Floor),
            morphoLendingAdapter.getEquityInCollateralAsset(),
            LeverageManagerHarness(address(leverageManager)).exposed_getFeeAdjustedTotalSupply(leverageToken),
            Math.Rounding.Floor
        );
        // The share value is less than half of the initial equity minted due to the share dilution from the fees,
        // and morpho borrow interest
        assertEq(userTotalShareValue, 3.254919226259702618 ether);

        previewData = leverageManager.previewWithdraw(leverageToken, userTotalShareValue);
        uint256 expectedTreasuryActionFee = Math.mulDiv(
            LeverageManagerHarness(address(leverageManager)).exposed_convertToShares(
                leverageToken,
                // 10% additional shares are burned for the token action fee
                Math.mulDiv(userTotalShareValue, 1.1e18, 1e18, Math.Rounding.Ceil),
                ExternalAction.Withdraw
            ),
            // 10% of the shares burned are minted to the treasury to cover the treasury action fee
            0.1e18,
            1e18,
            Math.Rounding.Ceil
        );

        uint256 userWethBalanceBeforeWithdraw = WETH.balanceOf(user);

        // Withdraw the share equity
        _withdraw(user, userTotalShareValue, previewData.debt);

        assertEq(leverageToken.balanceOf(user), 0);
        // Initial balance + management fee + treasury action fee
        assertEq(leverageToken.balanceOf(treasury), 0.495 ether + 0.405 ether + expectedTreasuryActionFee);
        assertEq(leverageToken.totalSupply(), leverageToken.balanceOf(treasury));

        assertEq(WETH.balanceOf(user), userWethBalanceBeforeWithdraw + previewData.collateral); // User receives the collateral asset
    }
}
