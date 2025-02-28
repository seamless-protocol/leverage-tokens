// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/console.sol";

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageManagerBase} from "./LeverageManagerBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract LeverageManagerWithdrawTest is LeverageManagerBase {
    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_withdraw_NoFee() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        StrategyState memory stateBefore = _getStrategyState();

        uint256 equityToWithdraw = 5 ether;
        (, uint256 debtToRepay,,) = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, debtToRepay);

        StrategyState memory stateAfter = _getStrategyState();

        // Ensure that collateral ratio is the same. Allow for 1 wei mistake but it must be in favour of strategy
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);
        assertEq(stateAfter.debt, stateBefore.debt - debtToRepay);
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
        (, uint256 debtToRepay,,) = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, debtToRepay);

        StrategyState memory stateAfter = _getStrategyState();
        uint256 equityInCollateralAssetAfter = morphoLendingAdapter.getEquityInCollateralAsset();

        // Ensure that collateral ratio is the same. Allow for 1 wei mistake but it must be in favour of strategy
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);

        // Ensure that after withdraw debt and collateral is 50% of what was initially after deposit
        assertEq(stateAfter.debt, 20000_000000 - 1); // 2000 USDC, -1 because of rounding
        assertEq(equityInCollateralAssetAfter, 5 ether);
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
        (, uint256 debtToRepay,,) = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, debtToRepay);

        StrategyState memory stateAfter = _getStrategyState();

        // Ensure that collateral ratio is the same. Allow for 1 wei mistake but it must be in favour of strategy
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);
    }

    function testFork_withdraw_fullWithdrawComparedToPartialWithdrawals() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 sharesAfterDeposit = _deposit(user, equityInCollateralAsset, collateralToAdd);

        uint256 sharesValueAfterDeposit = _convertToAssets(sharesAfterDeposit);
        (uint256 collateralAfterDeposit, uint256 debtAfterDeposit,,) =
            leverageManager.previewWithdraw(strategy, sharesValueAfterDeposit);

        uint256 equityToWithdraw = equityInCollateralAsset / 2;
        (uint256 collateralFirstTime, uint256 debtFirstTime,,) =
            leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, debtFirstTime);

        // Withdraw the rest
        equityToWithdraw = _convertToAssets(strategy.balanceOf(user));
        (uint256 collateralSecondTime, uint256 debtSecondTime,,) =
            leverageManager.previewWithdraw(strategy, equityToWithdraw);

        assertEq(collateralFirstTime + collateralSecondTime, collateralAfterDeposit);
        assertEq(debtFirstTime + debtSecondTime, debtAfterDeposit);
    }

    function testFork_withdraw_withFee() public {
        leverageManager.setStrategyActionFee(strategy, ExternalAction.Withdraw, 10_00); // 10%

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        uint256 equityInCollateralAssetAfterDeposit = morphoLendingAdapter.getEquityInCollateralAsset();

        // Withdraw 50% of equity
        uint256 equityToWithdraw = equityInCollateralAssetAfterDeposit / 2;
        (, uint256 debtToRepay,,) = leverageManager.previewWithdraw(strategy, equityToWithdraw);
        _withdraw(user, equityToWithdraw, debtToRepay);

        // Lower or equal because or rounding, theoretically perfect would be 4.5 ether
        assertEq(strategy.balanceOf(user), 4.5 ether + 1); // +1 because of rounding, equityToWithdraw is rounded down so shares to burn will also be a bit lower
    }
}
