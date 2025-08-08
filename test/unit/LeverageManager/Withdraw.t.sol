// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ActionDataV2, ExternalAction, LeverageTokenConfig, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerTest} from "../LeverageManager/LeverageManager.t.sol";

contract WithdrawTest is LeverageManagerTest {
    uint256 private COLLATERAL_RATIO_TARGET;

    function setUp() public override {
        super.setUp();

        COLLATERAL_RATIO_TARGET = 2 * _BASE_RATIO();

        _createNewLeverageToken(
            manager,
            COLLATERAL_RATIO_TARGET,
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(address(rebalanceAdapter)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    function testFuzz_withdraw_WithFees(uint256 collateral) public {
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Redeem, 0.05e4); // 5% fee
        _setTreasuryActionFee(ExternalAction.Redeem, 0.1e4); // 10% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 200 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 maxCollateralAfterFees = 200 ether * (MAX_BPS - 0.05e4) * (MAX_BPS - 0.1e4) / MAX_BPS_SQUARED;
        collateral = uint256(bound(collateral, 1, maxCollateralAfterFees));

        _testWithdraw(collateral, type(uint256).max);
    }

    function _testWithdraw(uint256 collateral, uint256 maxShares) internal {
        // First preview the redemption of shares
        ActionDataV2 memory previewData = leverageManager.previewWithdraw(leverageToken, collateral);

        uint256 shareTotalSupplyBefore = leverageToken.totalSupply();

        // This needs to be done this way because initial mock state mints total supply to address(1)
        // In order to keep the same total supply we need to burn and mint the same amount of shares
        vm.startPrank(address(leverageManager));
        leverageToken.burn(address(1), previewData.shares);
        leverageToken.mint(address(this), previewData.shares);
        vm.stopPrank();

        // Mint debt tokens to sender and approve leverage manager
        debtToken.mint(address(this), previewData.debt);
        debtToken.approve(address(leverageManager), previewData.debt);

        uint256 collateralBalanceBefore = collateralToken.balanceOf(address(this));
        uint256 debtBalanceBefore = debtToken.balanceOf(address(this));
        uint256 sharesBalanceBefore = leverageToken.balanceOf(address(this));

        // Execute redemption
        bool expectRevertDueToSlippage = previewData.shares > maxShares;
        if (expectRevertDueToSlippage) {
            vm.expectRevert(
                abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, previewData.shares, maxShares)
            );
        }
        ActionDataV2 memory withdrawData = leverageManager.withdraw(leverageToken, collateral, maxShares);

        if (expectRevertDueToSlippage) {
            return;
        }

        // Verify return values match preview
        assertEq(withdrawData.collateral, previewData.collateral);
        assertEq(withdrawData.debt, previewData.debt);
        assertEq(withdrawData.shares, previewData.shares);
        assertEq(withdrawData.tokenFee, previewData.tokenFee);
        assertEq(withdrawData.treasuryFee, previewData.treasuryFee);

        // Verify token transfers
        assertEq(collateralToken.balanceOf(address(this)) - collateralBalanceBefore, withdrawData.collateral);
        assertEq(debtBalanceBefore - debtToken.balanceOf(address(this)), withdrawData.debt);

        // Validate leverage token total supply and balance
        assertEq(leverageToken.totalSupply(), shareTotalSupplyBefore - withdrawData.shares + withdrawData.treasuryFee);
        assertEq(sharesBalanceBefore - leverageToken.balanceOf(address(this)), withdrawData.shares);
        assertEq(leverageToken.balanceOf(address(this)), sharesBalanceBefore - withdrawData.shares);

        // Verify that the treasury received the treasury action fee
        assertEq(leverageToken.balanceOf(treasury), withdrawData.treasuryFee);

        // Verify that if any collateral is returned, the amount of shares the user lost is non-zero
        if (withdrawData.collateral > 0) {
            assertGt(withdrawData.shares, 0);
        }

        // Share fees should be less than or equal to the shares redeemed
        assertLe(withdrawData.tokenFee + withdrawData.treasuryFee, withdrawData.shares);

        // Verify the collateral ratio is >= the collateral ratio before the redeem
        // We use the comparison collateralBefore * debtAfter >= collateralAfter * debtBefore, which is equivalent to
        // collateralRatioAfter >= collateralRatioBefore to avoid precision loss from division when calculating collateral
        // ratios
        assertGe(lendingAdapter.getCollateral() * debtBalanceBefore, collateralBalanceBefore * lendingAdapter.getDebt());
    }
}
