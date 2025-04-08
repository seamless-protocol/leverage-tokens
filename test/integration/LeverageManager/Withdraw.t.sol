// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {LeverageManagerTest} from "./LeverageManager.t.sol";
import {ActionData, LeverageTokenState} from "src/types/DataTypes.sol";

import {console2} from "forge-std/console2.sol";

contract LeverageManagerWithdrawTest is LeverageManagerTest {
    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_withdraw_NoFee() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

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
        _deposit(user, equityInCollateralAsset, collateralToAdd);

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
        uint256 shares = _deposit(user, equityInCollateralAsset, collateralToAdd);

        uint256 sharesValue = _convertToAssets(shares);
        uint256 debtToRepay = leverageManager.previewWithdraw(leverageToken, sharesValue).debt;
        _withdraw(user, sharesValue, debtToRepay);

        // Validate that almost all shares are burned, 1 wei always left because of debt rounding up
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
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        LeverageTokenState memory stateBefore = getLeverageTokenState();
        assertEq(stateBefore.collateralRatio, 1999999999950000000); // ~2x CR

        uint256 equityToWithdraw = 5 ether;
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        LeverageTokenState memory stateAfter = getLeverageTokenState();
        uint256 equityInCollateralAssetAfter = morphoLendingAdapter.getEquityInCollateralAsset();

        // Ensure that collateral ratio is the same (with some rounding error)
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertEq(stateAfter.collateralRatio, 2000000000050000000);

        // Ensure that after withdraw debt and collateral is 50% of what was initially after deposit
        assertEq(stateAfter.debt, 20000_000000 - 1); // 2000 USDC, -1 because of rounding
        assertEq(equityInCollateralAssetAfter, 5 ether);

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_PriceChangedBetweenWithdraws_CollateralRatioDoesNotChange() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

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
        // Deposit some assets initially
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 sharesAfterDeposit = _deposit(user, equityInCollateralAsset, collateralToAdd);

        // Withdraw everything
        uint256 sharesValueAfterDeposit = _convertToAssets(sharesAfterDeposit);
        ActionData memory previewDataAfterDeposit =
            leverageManager.previewWithdraw(leverageToken, sharesValueAfterDeposit);
        _withdraw(user, sharesValueAfterDeposit, previewDataAfterDeposit.debt);

        // Deposit again to create the same scenario
        sharesAfterDeposit = _deposit(user, equityInCollateralAsset, collateralToAdd);

        // Withdraw half of it
        uint256 equityToWithdraw = equityInCollateralAsset / 2;
        ActionData memory previewDataFirstTime = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewDataFirstTime.debt);

        // Withdraw the rest
        equityToWithdraw = _convertToAssets(leverageToken.balanceOf(user));
        ActionData memory previewDataSecondTime = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewDataSecondTime.debt);

        // Validate that in both cases we get the same amount of collateral and debt
        assertEq(previewDataFirstTime.collateral + previewDataSecondTime.collateral, previewDataAfterDeposit.collateral);
        assertEq(previewDataFirstTime.debt + previewDataSecondTime.debt, previewDataAfterDeposit.debt);

        // Validate that collateral token is properly transferred to user
        assertEq(WETH.balanceOf(user), previewDataFirstTime.collateral + previewDataSecondTime.collateral);
        assertLe(previewDataAfterDeposit.collateral, 2 * equityInCollateralAsset);
    }

    function testFork_withdraw_withFee() public {
        uint256 fee = 10_00; // 10%
        leverageManager.setTreasuryActionFee(ExternalAction.Withdraw, fee); // 10%
        leverageToken = _createNewLeverageToken(BASE_RATIO, 2 * BASE_RATIO, 3 * BASE_RATIO, fee, 0);
        morphoLendingAdapter =
            MorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)));

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        uint256 equityInCollateralAssetAfterDeposit = morphoLendingAdapter.getEquityInCollateralAsset();

        // Withdraw 50% of equity
        uint256 equityToWithdraw = equityInCollateralAssetAfterDeposit / 2;
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        // Lower or equal because or rounding, theoretically perfect would be 4.5 ether
        assertEq(leverageToken.balanceOf(user), 4.5 ether + 1); // +1 because of rounding, equityToWithdraw is rounded down so shares to burn will also be a bit lower

        assertEq(WETH.balanceOf(user), previewData.collateral); // User receives the collateral asset
        assertEq(WETH.balanceOf(treasury), previewData.treasuryFee); // Treasury receives the fee

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_RoundsSharesDown() public {
        address userA = makeAddr("userA");
        // Mock ETH price to be 4000 USDC
        (,, address oracle,,) = morphoLendingAdapter.marketParams();
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(4000e24));

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        // user deposits 10 ether of collateral
        _deposit(userA, equityInCollateralAsset, collateralToAdd);

        LeverageTokenState memory stateBefore = getLeverageTokenState();
        assertEq(stateBefore.collateralRatio, 1999999999950000000); // ~2x CR
        assertEq(leverageToken.balanceOf(userA), equityInCollateralAsset);

        // user withdraws as much equity as they can
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, 9999999999750000000);
        _withdraw(userA, 9999999999750000000, previewData.debt);
        assertEq(leverageToken.balanceOf(userA), 1);

        LeverageTokenState memory stateAfter = getLeverageTokenState();
        assertEq(stateAfter.collateralInDebtAsset, 0);
        assertEq(stateAfter.debt, 0);
        assertEq(stateAfter.equity, 0);

        assertEq(morphoLendingAdapter.getCollateral(), 2);
        assertEq(morphoLendingAdapter.getDebt(), 0);

        // Another user deposits 10 ether of equity
        address userB = makeAddr("userB");
        _deposit(userB, equityInCollateralAsset, collateralToAdd);
        console2.log("morpho collateral after userB deposit", morphoLendingAdapter.getCollateral());
        console2.log("morpho debt after userB deposit", morphoLendingAdapter.getDebt());

        // userA withdraws as much equity as they can
        ActionData memory previewDataB = leverageManager.previewWithdraw(leverageToken, 2);
        assertEq(previewDataB.collateral, 3);
        assertEq(previewDataB.debt, 1, "debt should be 2");
        assertEq(previewDataB.shares, 1, "shares should be 1");
        console2.log("leverage token total supply before userA second withdraw", leverageToken.totalSupply());
        console2.log("collateral ratio before userA second withdraw", getLeverageTokenState().collateralRatio);
        _withdraw(userA, 2, previewDataB.debt);
        console2.log("morpho collateral after userA second withdraw", morphoLendingAdapter.getCollateral());
        console2.log("morpho debt after userA second withdraw", morphoLendingAdapter.getDebt());
        assertEq(leverageToken.balanceOf(userA), 0);

        // userB withdraws as much equity as they can
        ActionData memory previewDataC = leverageManager.previewWithdraw(leverageToken, 9999999999999999998);
        _withdraw(userB, 9999999999999999998, previewDataC.debt);
        assertEq(leverageToken.balanceOf(userB), 1);

        LeverageTokenState memory stateAfterB = getLeverageTokenState();
        assertEq(stateAfterB.collateralInDebtAsset, 0);
        assertEq(stateAfterB.debt, 0);
        assertEq(stateAfterB.equity, 0);
    }

    function testFork_withdraw_RoundsSharesUp() public {
        address userA = makeAddr("userA");
        // Mock ETH price to be 4000 USDC
        (,, address oracle,,) = morphoLendingAdapter.marketParams();
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(4000e24));

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;

        // userA deposits 10 ether of collateral
        _deposit(userA, equityInCollateralAsset, collateralToAdd);

        LeverageTokenState memory stateBefore = getLeverageTokenState();
        assertEq(stateBefore.collateralRatio, 1999999999950000000); // ~2x CR
        assertEq(leverageToken.balanceOf(userA), equityInCollateralAsset);

        // userA withdraws as much equity as they can
        ActionData memory previewData = leverageManager.previewWithdraw(leverageToken, 9999999999750000000);
        _withdraw(userA, 9999999999750000000, previewData.debt);
        assertEq(leverageToken.balanceOf(userA), 0);

        LeverageTokenState memory stateAfter = getLeverageTokenState();
        assertEq(stateAfter.collateralInDebtAsset, 0);
        assertEq(stateAfter.debt, 0);
        assertEq(stateAfter.equity, 0);

        // userB deposits 10 ether of equity
        address userB = makeAddr("userB");
        _deposit(userB, equityInCollateralAsset, collateralToAdd);

        // userB withdraws as much equity as they can
        ActionData memory previewDataC = leverageManager.previewWithdraw(leverageToken, 9999999999750000000);
        _withdraw(userB, 9999999999750000000, previewDataC.debt);
        assertEq(leverageToken.balanceOf(userB), 0);

        LeverageTokenState memory stateAfterB = getLeverageTokenState();
        assertEq(stateAfterB.collateralInDebtAsset, 0);
        assertEq(stateAfterB.debt, 0);
        assertEq(stateAfterB.equity, 0);
    }
}
