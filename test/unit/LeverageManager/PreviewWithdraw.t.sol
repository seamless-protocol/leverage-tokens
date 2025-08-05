// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ActionDataV2, ExternalAction, LeverageTokenConfig, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerTest} from "../LeverageManager/LeverageManager.t.sol";

contract PreviewWithdrawTest is LeverageManagerTest {
    struct FuzzPreviewWithdrawParams {
        uint128 initialCollateral;
        uint128 initialDebt;
        uint128 initialSharesTotalSupply;
        uint128 collateral;
        uint16 fee;
        uint16 managementFee;
    }

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

    function test_previewWithdraw_WithFee() public {
        _setManagementFee(feeManagerRole, leverageToken, 0.1e4); // 10% management fee
        feeManager.chargeManagementFee(leverageToken);

        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Redeem, 0.05e4); // 5% fee

        _setTreasuryActionFee(feeManagerRole, ExternalAction.Redeem, 0.1e4); // 10% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 17.1 ether;
        ActionDataV2 memory previewData = leverageManager.previewWithdraw(leverageToken, collateral);

        assertEq(previewData.collateral, 17.1 ether);
        assertEq(previewData.debt, 17.1 ether);
        // 5% fee on gross shares = 17.1 * 0.05 = 0.855
        assertEq(previewData.tokenFee, 0.855 ether);
        // 10% fee on gross shares after token fee applied = (17.1 - 0.855) * 0.1 = 1.6245
        assertEq(previewData.treasuryFee, 1.6245 ether);
        assertEq(previewData.shares, 17.1 ether);

        skip(SECONDS_ONE_YEAR);

        previewData = leverageManager.previewWithdraw(leverageToken, collateral);

        // Share amounts are increased by ~10% due to management fee diluting share value
        assertEq(previewData.collateral, 17.1 ether);
        assertEq(previewData.debt, 17.1 ether);
        assertEq(previewData.shares, 18.81 ether);
        assertEq(previewData.tokenFee, 0.9405 ether);
        assertEq(previewData.treasuryFee, 1.78695 ether);
    }

    function test_previewWithdraw_WithoutFee() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 50 ether;
        ActionDataV2 memory previewData = leverageManager.previewWithdraw(leverageToken, collateral);

        assertEq(previewData.collateral, 50 ether);
        assertEq(previewData.debt, 25 ether);
        assertEq(previewData.shares, 50 ether);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_PreviewWithdraw_ZeroCollateral(
        uint128 initialCollateral,
        uint128 initialDebt,
        uint128 initialSharesTotalSupply
    ) public {
        MockLeverageManagerStateForAction memory beforeState = MockLeverageManagerStateForAction({
            collateral: initialCollateral,
            debt: initialDebt,
            sharesTotalSupply: initialSharesTotalSupply
        });

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 0;
        ActionDataV2 memory previewData = leverageManager.previewWithdraw(leverageToken, collateral);

        assertEq(previewData.collateral, 0);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_PreviewWithdraw_ZeroTotalSupply(uint128 initialCollateral, uint128 initialDebt) public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: initialCollateral, debt: initialDebt, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 200 ether;
        ActionDataV2 memory previewData = leverageManager.previewWithdraw(leverageToken, collateral);

        assertEq(previewData.collateral, 200 ether);
        assertEq(previewData.debt, 100 ether);
        assertEq(previewData.shares, 100 ether);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);

        previewData = leverageManager.previewRedeemV2(leverageToken, 0);
        assertEq(previewData.collateral, 0);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_PreviewWithdraw1(FuzzPreviewWithdrawParams memory params) public {
        // 0% to 99.99% token action fee
        params.fee = uint16(bound(params.fee, 0, MAX_ACTION_FEE));
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Redeem, params.fee);

        // 0% to 100% management fee
        params.managementFee = uint16(bound(params.managementFee, 0, MAX_MANAGEMENT_FEE));
        _setManagementFee(feeManagerRole, leverageToken, params.managementFee);

        // Bound initial debt in collateral asset to be less than or equal to initial collateral (1:1 exchange rate)
        params.initialDebt = uint128(bound(params.initialDebt, 0, params.initialCollateral));

        if (params.initialCollateral == 0 && params.initialDebt == 0) {
            params.initialSharesTotalSupply = 0;
        } else {
            params.initialSharesTotalSupply = uint128(bound(params.initialSharesTotalSupply, 1, type(uint128).max));
        }

        params.collateral = uint128(bound(params.collateral, 0, params.initialCollateral));

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: params.initialCollateral,
                debt: params.initialDebt, // 1:1 exchange rate for this test
                sharesTotalSupply: params.initialSharesTotalSupply
            })
        );

        LeverageTokenState memory prevState = leverageManager.getLeverageTokenState(leverageToken);

        ActionDataV2 memory previewData = leverageManager.previewWithdraw(leverageToken, params.collateral);

        // Calculate state after action
        uint256 newCollateralRatio = _computeLeverageTokenCRAfterAction(
            params.initialCollateral,
            params.initialDebt,
            previewData.collateral,
            previewData.debt,
            ExternalAction.Redeem
        );
        uint256 newDebt = params.initialDebt - previewData.debt;
        uint256 newCollateral = params.initialCollateral - previewData.collateral;
        uint256 newShares = params.initialSharesTotalSupply - previewData.shares;

        {
            uint256 shares =
                leverageManager.convertCollateralToShares(leverageToken, params.collateral, Math.Rounding.Ceil);
            (, uint256 tokenFee, uint256 treasuryFee) =
                leverageManager.exposed_computeFeesForGrossShares(leverageToken, shares, ExternalAction.Redeem);
            uint256 debt = leverageManager.convertSharesToDebt(leverageToken, shares, Math.Rounding.Ceil);

            // Validate if shares, collateral, debt, and fees are properly calculated and returned
            assertEq(previewData.shares, shares, "Preview shares incorrect");
            assertEq(previewData.collateral, params.collateral, "Preview collateral incorrect");
            assertEq(previewData.debt, debt, "Preview debt incorrect");
            assertEq(previewData.tokenFee, tokenFee, "Preview token fee incorrect");
            assertEq(previewData.treasuryFee, treasuryFee, "Preview treasury fee incorrect");
        }

        if (previewData.shares == 0) {
            assertEq(
                newCollateralRatio,
                prevState.collateralRatio,
                "Collateral ratio after redeem should be equal to before if zero shares are redeemed"
            );
        } else if (newDebt == 0) {
            assertEq(
                newCollateralRatio,
                type(uint256).max,
                "Collateral ratio after redeem should be equal to type(uint256).max if zero debt is left"
            );
        } else {
            if (newDebt > 10 && newCollateral > 10 && newShares > 10) {
                assertApproxEqRel(
                    newCollateralRatio,
                    prevState.collateralRatio,
                    _getAllowedCollateralRatioSlippage(Math.min(newDebt, newShares)),
                    "Collateral ratio after redeem should be within the allowed slippage"
                );
            }
            assertGe(
                newCollateralRatio,
                prevState.collateralRatio,
                "Collateral ratio after redeem should be greater than or equal to before"
            );
        }

        if (newCollateral == 0) {
            assertEq(newShares, 0, "New shares should be zero if collateral is zero");
            assertEq(newDebt, 0, "New debt should be zero if collateral is zero");
        }

        if (newShares == 0) {
            // Debt should be 0, but collateral does not need to be; the withdrawer may have specified an amount of collateral
            // that is less than the maximum amount for the shares burned
            assertEq(newDebt, 0, "New debt should be zero if shares are zero");
        }
    }
}
