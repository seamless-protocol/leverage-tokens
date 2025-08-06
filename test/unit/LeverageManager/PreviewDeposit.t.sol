// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ActionDataV2, ExternalAction, LeverageTokenConfig, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerTest} from "../LeverageManager/LeverageManager.t.sol";

contract PreviewDepositTest is LeverageManagerTest {
    struct FuzzPreviewDepositParams {
        uint128 initialCollateral;
        uint128 initialDebtInCollateralAsset;
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

    function test_previewDeposit_WithFee() public {
        _setManagementFee(feeManagerRole, leverageToken, 0.1e4); // 10% management fee

        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, 0.1e4); // 10% fee

        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Mint, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 20 ether;
        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateral);

        assertEq(previewData.collateral, collateral);
        assertEq(previewData.debt, 20 ether); // 1:2 exchange rate, 2x CR
        assertEq(previewData.tokenFee, 1 ether); // 5% fee applied on shares minted (20 ether * 0.05)
        assertEq(previewData.treasuryFee, 1.9 ether); // 10% fee applied on shares after token fee (19 ether * 0.1)
        assertEq(previewData.shares, 17.1 ether); // 20 ether shares - 1 ether token fee - 1.9 ether treasury fee

        skip(SECONDS_ONE_YEAR);

        previewData = leverageManager.previewDeposit(leverageToken, collateral);

        assertEq(previewData.collateral, collateral);
        assertEq(previewData.debt, 20 ether); // 1:2 exchange rate, 2x CR
        assertEq(previewData.shares, 18.81 ether); // Shares minted are increased by 10% due to management fee diluting share value
        assertEq(previewData.tokenFee, 1.1 ether); // 5% fee applied on shares minted (22 ether * 0.05)
        assertEq(previewData.treasuryFee, 2.09 ether); // 10% fee applied on shares after token fee (20.9 ether * 0.1)
    }

    function test_previewDeposit_WithoutFee() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 20 ether;
        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateral);

        assertEq(previewData.collateral, collateral);
        assertEq(previewData.debt, 10 ether);
        assertEq(previewData.shares, 20 ether);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewDeposit_ZeroCollateral(
        uint256 initialCollateral,
        uint256 initialDebt,
        uint256 initialSharesTotalSupply
    ) public {
        initialCollateral = initialSharesTotalSupply == 0
            ? 0
            : bound(initialCollateral, 0, type(uint256).max / initialSharesTotalSupply);
        initialDebt = initialCollateral == 0 ? 0 : bound(initialDebt, 0, initialCollateral - 1);

        MockLeverageManagerStateForAction memory beforeState = MockLeverageManagerStateForAction({
            collateral: initialCollateral,
            debt: initialDebt,
            sharesTotalSupply: initialSharesTotalSupply
        });
        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 0;
        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateral);

        assertEq(previewData.collateral, collateral);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewDeposit_ZeroTotalCollateral(uint128 initialTotalSupply, uint128 initialDebt) public {
        initialTotalSupply = uint128(bound(initialTotalSupply, 1, type(uint128).max));
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 0, debt: initialDebt, sharesTotalSupply: initialTotalSupply});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 2 ether;
        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateral);

        assertEq(previewData.collateral, collateral);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewDeposit_ZeroTotalDebt(uint128 initialCollateral, uint128 initialTotalSupply) public {
        initialTotalSupply = uint128(bound(initialTotalSupply, 1, type(uint128).max));
        MockLeverageManagerStateForAction memory beforeState = MockLeverageManagerStateForAction({
            collateral: initialCollateral,
            debt: 0,
            sharesTotalSupply: initialTotalSupply
        });

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 2 ether;
        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateral);

        assertEq(previewData.collateral, collateral);
        assertEq(previewData.debt, 0);

        uint256 expectedShares =
            leverageManager.convertCollateralToShares(leverageToken, collateral, Math.Rounding.Floor);

        assertEq(previewData.shares, expectedShares);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewDeposit_ZeroTotalSupply(uint128 initialCollateral, uint128 initialDebt) public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: initialCollateral, debt: initialDebt, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 collateral = 2 ether;
        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateral);

        // Follows 2x target ratio
        assertEq(previewData.collateral, 2 ether);
        assertEq(previewData.debt, 1 ether);

        uint256 expectedShares =
            leverageManager.convertCollateralToShares(leverageToken, collateral, Math.Rounding.Floor);

        assertEq(previewData.shares, expectedShares);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewDeposit(FuzzPreviewDepositParams memory params) public {
        // 0% to 99.99% token action fee
        params.fee = uint16(bound(params.fee, 0, MAX_ACTION_FEE));
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Mint, params.fee);

        // 0% to 100% management fee
        params.managementFee = uint16(bound(params.managementFee, 0, MAX_MANAGEMENT_FEE));
        _setManagementFee(feeManagerRole, leverageToken, params.managementFee);

        // Bound initial debt in collateral asset to be less than or equal to initial collateral (1:1 exchange rate)
        params.initialDebtInCollateralAsset =
            uint128(bound(params.initialDebtInCollateralAsset, 0, params.initialCollateral));

        if (params.initialCollateral == 0 && params.initialDebtInCollateralAsset == 0) {
            params.initialSharesTotalSupply = 0;
        } else {
            params.initialSharesTotalSupply = uint128(bound(params.initialSharesTotalSupply, 1, type(uint128).max));
        }

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: params.initialCollateral,
                debt: params.initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: params.initialSharesTotalSupply
            })
        );

        // Bound collateral to avoid overflows in LM.convertCollateralToShares
        params.collateral = params.initialSharesTotalSupply == 0
            ? params.collateral
            : uint128(bound(params.collateral, 0, type(uint128).max / params.initialSharesTotalSupply));

        LeverageTokenState memory prevState = leverageManager.getLeverageTokenState(leverageToken);

        ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, params.collateral);

        // Calculate state after action
        uint256 newCollateralRatio = _computeLeverageTokenCRAfterAction(
            params.initialCollateral,
            params.initialDebtInCollateralAsset,
            previewData.collateral,
            previewData.debt,
            ExternalAction.Mint
        );

        {
            uint256 shares =
                leverageManager.convertCollateralToShares(leverageToken, params.collateral, Math.Rounding.Floor);
            (uint256 sharesAfterFee, uint256 tokenFee) =
                leverageManager.exposed_computeTokenFee(leverageToken, shares, ExternalAction.Mint);
            uint256 treasuryFee = leverageManager.exposed_computeTreasuryFee(ExternalAction.Mint, sharesAfterFee);
            uint256 debt = leverageManager.convertSharesToDebt(leverageToken, shares, Math.Rounding.Floor);

            // Validate if shares, collateral, debt, and fees are properly calculated and returned
            assertEq(previewData.shares, sharesAfterFee - treasuryFee, "Preview shares incorrect");
            assertEq(previewData.collateral, params.collateral, "Preview collateral incorrect");
            assertEq(previewData.debt, debt, "Preview debt incorrect");
            assertEq(previewData.tokenFee, tokenFee, "Preview token fee incorrect");
            assertEq(previewData.treasuryFee, treasuryFee, "Preview treasury fee incorrect");
        }

        // If no shares are minted, the deposit is a essentially a donation of equity
        if (previewData.shares == 0) {
            if (prevState.collateralRatio != type(uint256).max) {
                assertGe(
                    newCollateralRatio,
                    prevState.collateralRatio,
                    "Collateral ratio after deposit should be greater than or equal to before if zero shares are minted when the strategy has debt (collateral ratio != type(uint256).max)"
                );
            } else {
                assertGe(
                    newCollateralRatio,
                    COLLATERAL_RATIO_TARGET,
                    "Collateral ratio after deposit should be greater than or equal to target if zero shares are minted"
                );
            }
        } else {
            if (params.initialCollateral == 0 || params.initialDebtInCollateralAsset == 0) {
                if (params.initialCollateral == 0) {
                    // Precision of new CR wrt the target depends on the amount of collateral added when the strategy is empty
                    assertApproxEqRel(
                        newCollateralRatio,
                        COLLATERAL_RATIO_TARGET,
                        _getAllowedCollateralRatioSlippage(params.collateral),
                        "Collateral ratio after deposit when there is zero collateral should be within the allowed slippage"
                    );
                    assertGe(
                        newCollateralRatio,
                        COLLATERAL_RATIO_TARGET,
                        "Collateral ratio after deposit when there is zero collateral should be greater than or equal to target"
                    );
                } else if (params.initialDebtInCollateralAsset == 0 && params.initialSharesTotalSupply == 0) {
                    assertGe(
                        newCollateralRatio,
                        COLLATERAL_RATIO_TARGET,
                        "Collateral ratio after deposit when there is zero debt and zero total supply should be greater than or equal to target"
                    );
                }
            } else {
                assertApproxEqRel(
                    newCollateralRatio,
                    prevState.collateralRatio,
                    _getAllowedCollateralRatioSlippage(
                        Math.min(
                            Math.min(params.initialSharesTotalSupply, params.initialCollateral),
                            params.initialDebtInCollateralAsset
                        )
                    ),
                    "Collateral ratio after deposit should be within the allowed slippage"
                );
                assertGe(
                    newCollateralRatio,
                    prevState.collateralRatio,
                    "Collateral ratio after deposit should be greater than or equal to before"
                );
            }
        }
    }
}
