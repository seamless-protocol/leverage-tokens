// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ActionData, LeverageTokenConfig, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerTest} from "../LeverageManager/LeverageManager.t.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract PreviewActionTest is LeverageManagerTest {
    function setUp() public override {
        super.setUp();

        _createNewLeverageToken(
            manager,
            2e18,
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(address(0)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    function test_previewAction_WithFee() public {
        _setManagementFee(feeManagerRole, leverageToken, 0.1e4); // 10% management fee
        feeManager.chargeManagementFee(leverageToken);

        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, 0.1e4); // 10% fee
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Redeem, 0.1e4); // 10% fee

        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Mint, 0.05e4); // 5% fee
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Redeem, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equity = 10 ether;
        ActionData memory previewData =
            leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Mint);

        assertEq(previewData.collateral, 20 ether);
        assertEq(previewData.debt, 20 ether);
        // 5% fee on equity (1 ether shares), 10% fee on shares (19 ether shares * 0.1 = 1.9 ether shares)
        // 20 ether shares - 1 ether shares - 1.9 ether shares = 17.1 ether shares
        assertEq(previewData.shares, 17.1 ether);
        // 5% fee on equity in collateral asset
        assertEq(previewData.tokenFee, 0.5 ether);
        // 10% fee on shares
        assertEq(previewData.treasuryFee, 1.9 ether);

        previewData = leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Redeem);

        assertEq(previewData.collateral, 20 ether);
        assertEq(previewData.debt, 20 ether);
        // 5% fee on equity (1 ether shares), 10% fee on shares (21 ether shares * 0.1 = 2.1 ether shares)
        assertEq(previewData.shares, 23.1 ether);
        // 5% fee on equity in collateral asset
        assertEq(previewData.tokenFee, 0.5 ether);
        // 10% fee on shares
        assertEq(previewData.treasuryFee, 2.1 ether);

        skip(SECONDS_ONE_YEAR);

        previewData = leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Mint);

        // 10% management fee affects the shares but everything else is the same
        assertEq(previewData.collateral, 20 ether);
        assertEq(previewData.debt, 20 ether);
        assertEq(previewData.shares, 18.81 ether); // Shares minted are increased by 10% due to management fee diluting share value
        assertEq(previewData.tokenFee, 0.5 ether); // 5% fee on equity in collateral asset
        assertEq(previewData.treasuryFee, 2.09 ether);

        previewData = leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Redeem);

        // 10% management fee affects the shares but everything else is the same
        assertEq(previewData.collateral, 20 ether);
        assertEq(previewData.debt, 20 ether);
        assertEq(previewData.shares, 25.41 ether); // Shares burned are increased by 10% due to management fee diluting share value
        assertEq(previewData.tokenFee, 0.5 ether); // 5% fee on equity in collateral asset
        assertEq(previewData.treasuryFee, 2.31 ether);
    }

    function test_previewAction_WithFee_ZeroSharesForEquity() public {
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Mint, 0.05e4); // 5% fee
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Redeem, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 10 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        // 0 shares can be minted for 1 wei of equity
        uint256 equity = 1;
        ActionData memory previewData =
            leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Mint);

        assertEq(previewData.collateral, 0);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 1);
        assertEq(previewData.treasuryFee, 0);

        // 1 share can be burned for 1 wei of equity because of shares rounding up for redeems
        previewData = leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Redeem);
        assertEq(previewData.collateral, 10);
        assertEq(previewData.debt, 10);
        assertEq(previewData.shares, 1);
        assertEq(previewData.tokenFee, 1);
        assertEq(previewData.treasuryFee, 0);
    }

    function test_previewAction_WithoutFee() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToAdd = 10 ether;
        ActionData memory previewData =
            leverageManager.exposed_previewAction(leverageToken, equityToAdd, ExternalAction.Mint);

        assertEq(previewData.collateral, 20 ether);
        assertEq(previewData.debt, 10 ether);
        assertEq(previewData.shares, 20 ether);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);

        previewData = leverageManager.exposed_previewAction(leverageToken, equityToAdd, ExternalAction.Redeem);

        assertEq(previewData.collateral, 20 ether);
        assertEq(previewData.debt, 10 ether);
        assertEq(previewData.shares, 20 ether);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function test_previewAction_ZeroEquity() public view {
        uint256 equity = 0;
        ActionData memory previewData =
            leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Mint);

        assertEq(previewData.collateral, 0);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
        previewData = leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Redeem);

        assertEq(previewData.collateral, 0);
        assertEq(previewData.debt, 0);
        assertEq(previewData.shares, 0);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewAction_MintZeroSharesTotalSupply(uint128 initialCollateral, uint128 initialDebt) public {
        initialDebt = initialCollateral == 0 ? 0 : uint128(bound(initialDebt, 0, initialCollateral - 1));

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: initialCollateral, debt: initialDebt, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equity = 1 ether;

        ActionData memory previewData =
            leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Mint);

        // Follows 2x target ratio
        assertEq(previewData.collateral, 2 ether);
        assertEq(previewData.debt, 1 ether);

        uint256 expectedShares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Mint);
        assertEq(previewData.shares, expectedShares);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);

        expectedShares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Redeem);
        previewData = leverageManager.exposed_previewAction(leverageToken, equity, ExternalAction.Redeem);
        assertEq(previewData.collateral, 2 ether);
        assertEq(previewData.debt, 1 ether);
        assertEq(previewData.shares, expectedShares);
        assertEq(previewData.tokenFee, 0);
        assertEq(previewData.treasuryFee, 0);
    }

    function testFuzz_previewAction(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityInCollateralAsset,
        uint16 fee,
        uint16 managementFee,
        uint8 actionNum
    ) public {
        ExternalAction action = ExternalAction(actionNum % 2);
        fee = uint16(bound(fee, 0, MAX_FEE)); // 0% to 100% fee
        leverageManager.exposed_setLeverageTokenActionFee(leverageToken, action, fee);

        managementFee = uint16(bound(managementFee, 0, MAX_FEE)); // 0% to 100% management fee
        _setManagementFee(feeManagerRole, leverageToken, managementFee);

        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));

        if (initialCollateral == 0 && initialDebtInCollateralAsset == 0) {
            sharesTotalSupply = 0;
        } else {
            sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));
        }

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: sharesTotalSupply
            })
        );

        // Ensure the collateral being added does not result in overflows due to mocked value sizes
        if (action == ExternalAction.Mint) {
            equityInCollateralAsset = uint128(bound(equityInCollateralAsset, 1, type(uint96).max));
        } else {
            equityInCollateralAsset =
                uint128(bound(equityInCollateralAsset, 0, _convertToAssets(sharesTotalSupply, action)));
        }

        // Get state prior to action
        LeverageTokenState memory prevState = leverageManager.getLeverageTokenState(leverageToken);

        ActionData memory previewData =
            leverageManager.exposed_previewAction(leverageToken, equityInCollateralAsset, action);

        // Calculate state after action
        (, uint256 newDebt, uint256 newCollateralRatio) = _getNewLeverageTokenState(
            initialCollateral, initialDebtInCollateralAsset, previewData.collateral, previewData.debt, action
        );

        {
            (uint256 equityForSharesAfterFees, uint256 tokenFee) =
                leverageManager.exposed_computeTokenFee(leverageToken, equityInCollateralAsset, action);

            (uint256 collateralForLeverageToken, uint256 debtForLeverageToken) = leverageManager
                .exposed_computeCollateralAndDebtForAction(leverageToken, equityInCollateralAsset, action);
            uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equityForSharesAfterFees, action);
            uint256 treasuryFee = leverageManager.exposed_computeTreasuryFee(action, shares);

            // Validate if shares, collateral, debt, and fees are properly calculated and returned
            assertEq(previewData.shares, action == ExternalAction.Mint ? shares - treasuryFee : shares + treasuryFee);
            assertEq(previewData.collateral, collateralForLeverageToken);
            assertEq(previewData.debt, debtForLeverageToken);
            assertEq(previewData.tokenFee, tokenFee);
            assertEq(previewData.treasuryFee, treasuryFee);
        }

        // If full redeem is done then the collateral ratio should be max
        if (_isFullRedeem(initialDebtInCollateralAsset, previewData.debt, action)) {
            assertEq(newCollateralRatio, type(uint256).max);
            return;
        }

        // If leverage token was initially empty then action should be done by respecting the target ratio
        if (_isLeverageTokenEmpty(initialCollateral)) {
            assertEq(newCollateralRatio, 2 * _BASE_RATIO());
            return;
        }

        // If initially leverage token had something in collateral but no debt ratio should change for the better
        if (initialDebtInCollateralAsset == 0) {
            assertLe(newCollateralRatio, prevState.collateralRatio);
            return;
        }

        // Otherwise, the action should be done by respecting the current collateral ratio
        // There is some tolerance on collateral ratio due to rounding depending on debt size
        // It is important to calculate tolerance with smaller debt (for mint before action for redeem after action)

        uint256 respectiveDebt = action == ExternalAction.Mint ? initialDebtInCollateralAsset : newDebt;
        uint256 from = action == ExternalAction.Mint ? newCollateralRatio : prevState.collateralRatio;
        uint256 to = action == ExternalAction.Mint ? prevState.collateralRatio : newCollateralRatio;

        assertApproxEqRel(
            from,
            to,
            _getAllowedCollateralRatioSlippage(respectiveDebt),
            "Collateral ratio after action should be within the allowed slippage"
        );
        assertGe(
            newCollateralRatio,
            prevState.collateralRatio,
            "Collateral ratio after action should be greater than or equal to before"
        );
    }

    function _getNewLeverageTokenState(
        uint256 initialCollateral,
        uint256 initialDebtInCollateralAsset,
        uint256 collateralChange,
        uint256 debtChange,
        ExternalAction action
    ) internal view returns (uint256 newCollateral, uint256 newDebt, uint256 newCollateralRatio) {
        debtChange = lendingAdapter.convertDebtToCollateralAsset(debtChange);

        newCollateral =
            action == ExternalAction.Mint ? initialCollateral + collateralChange : initialCollateral - collateralChange;

        newDebt = action == ExternalAction.Mint
            ? initialDebtInCollateralAsset + debtChange
            : initialDebtInCollateralAsset - debtChange;

        newCollateralRatio =
            newDebt != 0 ? Math.mulDiv(newCollateral, _BASE_RATIO(), newDebt, Math.Rounding.Floor) : type(uint256).max;

        return (newCollateral, newDebt, newCollateralRatio);
    }

    function _isFullRedeem(uint256 initialDebt, uint256 debtChange, ExternalAction action)
        internal
        view
        returns (bool)
    {
        return action == ExternalAction.Redeem && initialDebt == lendingAdapter.convertDebtToCollateralAsset(debtChange);
    }

    function _isLeverageTokenEmpty(uint256 collateral) private pure returns (bool) {
        return collateral == 0;
    }

    struct MockLeverageManagerStateForAction {
        uint256 collateral;
        uint256 debt;
        uint256 sharesTotalSupply;
    }

    function _prepareLeverageManagerStateForAction(MockLeverageManagerStateForAction memory state) internal {
        lendingAdapter.mockDebt(state.debt);
        lendingAdapter.mockCollateral(state.collateral);

        uint256 debtInCollateralAsset = lendingAdapter.convertDebtToCollateralAsset(state.debt);
        _mockState_ConvertToShares(
            ConvertToSharesState({
                totalEquity: state.collateral > debtInCollateralAsset ? state.collateral - debtInCollateralAsset : 0,
                sharesTotalSupply: state.sharesTotalSupply
            })
        );
    }

    /// @dev The allowed slippage in collateral ratio of the leverage token after a mint should scale with the size of the
    /// initial debt in the leverage token, as smaller strategies may incur a higher collateral ratio delta after the
    /// mint due to rounding.
    ///
    /// For example, if the initial collateral is 3 and the initial debt is 1 (with collateral and debt normalized) then the
    /// collateral ratio is 300000000, with 2 shares total supply. If a mint of 1 equity is made, then the required collateral
    /// is 2 and the required debt is 0, so the resulting collateral is 5 and the debt is 1:
    ///
    ///    sharesMinted = convertToShares(1) = equityToAdd * (existingSharesTotalSupply + offset) / (existingEquity + offset) = 1 * 3 / 3 = 1
    ///    collateralToAdd = existingCollateral * sharesMinted / sharesTotalSupply = 3 * 1 / 2 = 2 (1.5 rounded up)
    ///    debtToBorrow = existingDebt * sharesMinted / sharesTotalSupply = 1 * 1 / 2 = 0 (0.5 rounded down)
    ///
    /// The resulting collateral ratio is 500000000, which is a ~+66.67% change from the initial collateral ratio.
    ///
    /// As the intial debt scales up in size, the allowed slippage should scale down as more precision can be achieved
    /// for the collateral ratio:
    ///    initialDebt < 100: 1e18 (100% slippage)
    ///    initialDebt < 1000: 0.1e18 (10% slippage)
    ///    initialDebt < 10000: 0.01e18 (1% slippage)
    ///    initialDebt < 100000: 0.001e18 (0.1% slippage)
    ///    initialDebt < 1000000: 0.0001e18 (0.01% slippage)
    ///    initialDebt < 10000000: 0.00001e18 (0.001% slippage)
    ///    initialDebt < 100000000: 0.000001e18 (0.0001% slippage)
    ///    initialDebt < 1000000000: 0.0000001e18 (0.00001% slippage)
    ///    initialDebt >= 1000000000: 0.00000001e18 (0.000001% slippage)
    ///
    /// Note: We can at minimum support up to 0.00000001e18 (0.000001% slippage) due to the base collateral ratio
    ///       being 1e18
    function _getAllowedCollateralRatioSlippage(uint256 initialDebt)
        internal
        pure
        returns (uint256 allowedSlippagePercentage)
    {
        if (initialDebt == 0) {
            return 1e18;
        }

        uint256 i = Math.log10(initialDebt);

        // This is the minimum slippage that we can support due to the precision of the collateral ratio being
        // 1e18 (1e18 / 1e18 = 1e0 = 1)
        if (i > 18) return 1;

        // If i <= 1, that means initialDebt < 100, thus slippage = 1e18
        // Otherwise slippage = 1e18 / (10^(i - 1))
        return (i <= 1) ? 1e18 : (1e18 / (10 ** (i - 1)));
    }
}
