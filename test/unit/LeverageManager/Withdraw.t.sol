// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {console} from "forge-std/console.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {PreviewActionTest} from "./PreviewAction.t.sol";

contract WithdrawTest is PreviewActionTest {
    function test_withdraw_WithFee() public {
        _setStrategyActionFee(strategy, ExternalAction.Withdraw, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 200 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToWithdraw = 10 ether;
        _testWithdraw(equityToWithdraw, type(uint256).max);
    }

    function test_withdraw_WithoutFee() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 200 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToWithdraw = 10 ether;
        _testWithdraw(equityToWithdraw, type(uint256).max);
    }

    function test_withdraw_ZeroEquity() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 200 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        _testWithdraw(0, type(uint256).max);
    }

    function testFuzz_withdraw_RevertIf_SlippageTooHigh(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToWithdrawInCollateralAsset,
        uint16 fee
    ) public {
        fee = uint16(bound(fee, 0, 1e4));
        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _setStrategyActionFee(strategy, ExternalAction.Withdraw, fee);

        vm.assume(initialCollateral > initialDebtInCollateralAsset);
        vm.assume(equityToWithdrawInCollateralAsset > 0);

        // Preview the withdrawal
        (,, uint256 expectedShares,) = leverageManager.previewWithdraw(strategy, equityToWithdrawInCollateralAsset);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, expectedShares, expectedShares - 1)
        );
        leverageManager.withdraw(strategy, equityToWithdrawInCollateralAsset, expectedShares - 1);
    }

    function testFuzz_withdraw(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToWithdrawInCollateralAsset,
        uint16 fee
    ) public {
        fee = uint16(bound(fee, 0, 1e4));
        _setStrategyActionFee(strategy, ExternalAction.Withdraw, fee);

        // Bound debt to be lower than collateral asset and share total supply to be greater than 0 otherwise withdraw can not work
        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset,
                sharesTotalSupply: sharesTotalSupply
            })
        );

        // Ensure withdrawal amount doesn't exceed available equity
        equityToWithdrawInCollateralAsset =
            uint128(bound(equityToWithdrawInCollateralAsset, 0, initialCollateral - initialDebtInCollateralAsset));

        _testWithdraw(equityToWithdrawInCollateralAsset, type(uint256).max);
    }

    function _testWithdraw(uint256 equityToWithdrawInCollateralAsset, uint256 maxShares) internal {
        // First preview the withdrawal
        (
            uint256 expectedCollateralToRemove,
            uint256 expectedDebtToRepay,
            uint256 expectedSharesAfterFee,
            uint256 expectedSharesFee
        ) = leverageManager.previewWithdraw(strategy, equityToWithdrawInCollateralAsset);

        uint256 shareTotalSupplyBefore = strategy.totalSupply();

        vm.assume(expectedSharesAfterFee <= shareTotalSupplyBefore);

        // This needs to be done this way because initial mock state mints total supply to address(1)
        // In order to keep the same total supply we need to burn and mint the same amount of shares
        vm.startPrank(address(leverageManager));
        strategy.burn(address(1), expectedSharesAfterFee);
        strategy.mint(address(this), expectedSharesAfterFee);
        vm.stopPrank();

        // Mint debt tokens to sender and approve leverage manager
        debtToken.mint(address(this), expectedDebtToRepay);
        debtToken.approve(address(leverageManager), expectedDebtToRepay);

        uint256 collateralBalanceBefore = collateralToken.balanceOf(address(this));
        uint256 debtBalanceBefore = debtToken.balanceOf(address(this));

        // Execute withdrawal
        (
            uint256 actualCollateralToRemove,
            uint256 actualDebtToRepay,
            uint256 actualSharesAfterFee,
            uint256 actualSharesFee
        ) = leverageManager.withdraw(strategy, equityToWithdrawInCollateralAsset, maxShares);

        // Verify return values match preview
        assertEq(actualCollateralToRemove, expectedCollateralToRemove);
        assertEq(actualDebtToRepay, expectedDebtToRepay);
        assertEq(actualSharesAfterFee, expectedSharesAfterFee);
        assertEq(actualSharesFee, expectedSharesFee);

        // Verify token transfers
        assertEq(collateralToken.balanceOf(address(this)) - collateralBalanceBefore, actualCollateralToRemove);
        assertEq(debtBalanceBefore - debtToken.balanceOf(address(this)), actualDebtToRepay);

        // Validate strategy total supply and balance
        assertEq(strategy.totalSupply(), shareTotalSupplyBefore - actualSharesAfterFee);
        assertEq(strategy.balanceOf(address(this)), 0);
    }
}
