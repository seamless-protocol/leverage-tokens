// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/console.sol";

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageManagerBase} from "./LeverageManagerBase.t.sol";
import {ActionData, StrategyState} from "src/types/DataTypes.sol";

contract LeverageManagerWithdrawTest is LeverageManagerBase {
    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_withdraw_NoFee() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        StrategyState memory stateBefore = _getStrategyState();

        uint256 equityToWithdraw = 5 ether;
        ActionData memory previewData = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        StrategyState memory stateAfter = _getStrategyState();

        // Ensure that collateral ratio is the same. Allow for 1 wei mistake but it must be in favour of strategy
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);
        assertEq(stateAfter.debt, stateBefore.debt - previewData.debt);

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_ZeroAmount() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        ActionData memory previewData = leverageManager.previewWithdraw(strategy, 0);
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
        uint256 debtToRepay = leverageManager.previewWithdraw(strategy, sharesValue).debt;
        _withdraw(user, sharesValue, debtToRepay);

        // Validate that almost all shares are burned, 1 wei always left because of debt rounding up
        assertEq(strategy.totalSupply(), 1);

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

        StrategyState memory stateBefore = _getStrategyState();

        uint256 equityToWithdraw = 5 ether;
        ActionData memory previewData = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        StrategyState memory stateAfter = _getStrategyState();
        uint256 equityInCollateralAssetAfter = morphoLendingAdapter.getEquityInCollateralAsset();

        // Ensure that collateral ratio is the same. Allow for 1 wei mistake but it must be in favour of strategy
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);

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

        StrategyState memory stateBefore = _getStrategyState();

        uint256 equityToWithdraw = 5 ether;
        ActionData memory previewData = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        StrategyState memory stateAfter = _getStrategyState();

        // Ensure that collateral ratio is the same. Allow for 1 wei mistake but it must be in favour of strategy
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }

    function testFork_withdraw_fullWithdrawComparedToPartialWithdrawals() public {
        // Deposit some assets initially
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 sharesAfterDeposit = _deposit(user, equityInCollateralAsset, collateralToAdd);

        // Withdraw everything
        uint256 sharesValueAfterDeposit = _convertToAssets(sharesAfterDeposit);
        ActionData memory previewDataAfterDeposit = leverageManager.previewWithdraw(strategy, sharesValueAfterDeposit);
        _withdraw(user, sharesValueAfterDeposit, previewDataAfterDeposit.debt);

        // Deposit again to create the same scenario
        sharesAfterDeposit = _deposit(user, equityInCollateralAsset, collateralToAdd);

        // Withdraw half of it
        uint256 equityToWithdraw = equityInCollateralAsset / 2;
        ActionData memory previewDataFirstTime = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewDataFirstTime.debt);

        // Withdraw the rest
        equityToWithdraw = _convertToAssets(strategy.balanceOf(user));
        ActionData memory previewDataSecondTime = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewDataSecondTime.debt);

        // Validate that in both cases we get the same amount of collateral and debt
        assertEq(previewDataFirstTime.collateral + previewDataSecondTime.collateral, previewDataAfterDeposit.collateral);
        assertEq(previewDataFirstTime.debt + previewDataSecondTime.debt, previewDataAfterDeposit.debt);

        // Validate that collateral token is properly transferred to user
        assertEq(WETH.balanceOf(user), previewDataFirstTime.collateral + previewDataSecondTime.collateral);
        assertLe(previewDataAfterDeposit.collateral, 2 * equityInCollateralAsset);
    }

    function testFork_withdraw_withFee() public {
        leverageManager.setTreasuryActionFee(ExternalAction.Withdraw, 10_00); // 10%
        leverageManager.setStrategyActionFee(strategy, ExternalAction.Withdraw, 10_00); // 10%

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        uint256 equityInCollateralAssetAfterDeposit = morphoLendingAdapter.getEquityInCollateralAsset();

        // Withdraw 50% of equity
        uint256 equityToWithdraw = equityInCollateralAssetAfterDeposit / 2;
        ActionData memory previewData = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, previewData.debt);

        // Lower or equal because or rounding, theoretically perfect would be 4.5 ether
        assertEq(strategy.balanceOf(user), 4.5 ether + 1); // +1 because of rounding, equityToWithdraw is rounded down so shares to burn will also be a bit lower

        assertEq(WETH.balanceOf(user), previewData.collateral); // User receives the collateral asset
        assertEq(WETH.balanceOf(treasury), previewData.treasuryFee); // Treasury receives the fee

        assertEq(WETH.balanceOf(user), previewData.collateral);
    }
}
