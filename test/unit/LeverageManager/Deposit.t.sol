// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {CollateralRatios, StrategyState} from "src/types/DataTypes.sol";
import {PreviewActionTest} from "../LeverageManager/PreviewAction.t.sol";

contract DepositTest is PreviewActionTest {
    function test_deposit() public {
        // collateral:debt is 2:1
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(0.5e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 200 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        _testDeposit(equityToAddInCollateralAsset, 0);
    }

    function testFuzz_deposit_SharesTotalSupplyGreaterThanZero(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToAddInCollateralAsset
    ) public {
        initialCollateral = uint128(bound(initialCollateral, 1, type(uint128).max));
        initialDebtInCollateralAsset =
            initialCollateral == 1 ? 0 : uint128(bound(initialDebtInCollateralAsset, 1, initialCollateral - 1));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: sharesTotalSupply
            })
        );

        // Ensure the collateral being added does not result in overflows due to mocked value sizes
        equityToAddInCollateralAsset = uint128(bound(equityToAddInCollateralAsset, 1, type(uint96).max));

        uint256 allowedSlippage = _getAllowedCollateralRatioSlippage(initialDebtInCollateralAsset);
        _testDeposit(equityToAddInCollateralAsset, allowedSlippage);
    }

    function test_deposit_EquityToDepositIsZero() public {
        // CR is 3x
        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({collateral: 9, debt: 3, sharesTotalSupply: 3})
        );

        uint256 equityToAddInCollateralAsset = 0;
        (uint256 collateralToAdd, uint256 debtToBorrow,,) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        assertEq(collateralToAdd, 0);
        assertEq(debtToBorrow, 0);

        _testDeposit(equityToAddInCollateralAsset, 0);
    }

    function test_deposit_IsEmptyStrategy() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 0, debt: 0, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 20 ether; // 2x CR

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        // Does not revert
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, equityToAddInCollateralAsset - 1);

        StrategyState memory afterState = leverageManager.getStrategyState(strategy);
        assertEq(afterState.collateralInDebtAsset, 20 ether); // 1:1 exchange rate, 2x CR
        assertEq(afterState.debt, 10 ether);
        assertEq(afterState.collateralRatio, 2 * _BASE_RATIO());
    }

    function test_deposit_ZeroSharesTotalSupplyWithDust() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 3, debt: 1, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToAddInCollateralAsset = 1 ether;
        uint256 expectedCollateralToAdd = 2 ether; // 2x target CR
        uint256 expectedDebtToBorrow = 1 ether;
        uint256 expectedShares = Math.mulDiv(
            equityToAddInCollateralAsset,
            10 ** _DECIMALS_OFFSET(),
            beforeState.collateral - beforeState.debt + 1, // 1:1 collateral to debt exchange rate in this test
            Math.Rounding.Floor
        );

        deal(address(collateralToken), address(this), expectedCollateralToAdd);
        collateralToken.approve(address(leverageManager), expectedCollateralToAdd);

        (uint256 collateralAdded, uint256 debtBorrowed, uint256 sharesReceived, uint256 shareFeeCharged) =
            leverageManager.deposit(strategy, equityToAddInCollateralAsset, expectedShares);

        assertEq(collateralAdded, expectedCollateralToAdd);
        assertEq(debtBorrowed, expectedDebtToBorrow);
        assertEq(sharesReceived, expectedShares);
        assertEq(shareFeeCharged, 0);

        StrategyState memory afterState = leverageManager.getStrategyState(strategy);
        assertEq(afterState.collateralInDebtAsset, expectedCollateralToAdd + beforeState.collateral);
        assertEq(afterState.debt, expectedDebtToBorrow + beforeState.debt); // 1:1 collateral to debt exchange rate, 2x target CR
        assertEq(
            afterState.collateralRatio,
            Math.mulDiv(
                expectedCollateralToAdd + beforeState.collateral,
                _BASE_RATIO(),
                expectedDebtToBorrow + beforeState.debt,
                Math.Rounding.Floor
            )
        );
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_SlippageIsTooHigh(uint128 sharesSlippage) public {
        vm.assume(sharesSlippage > 0);

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 10 ether})
        );

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd,, uint256 shares,) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        uint256 minShares = shares + sharesSlippage; // More than previewed

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, shares, minShares));
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, minShares);
    }

    function _testDeposit(uint256 equityToAddInCollateralAsset, uint256 collateralRatioDeltaRelative) internal {
        StrategyState memory beforeState = leverageManager.getStrategyState(strategy);
        uint256 beforeSharesTotalSupply = strategy.totalSupply();

        // The assertion for collateral ratio before and after the deposit in this helper only makes sense to use
        // if the strategy has totalSupply > 0 before deposit, as a deposit of equity into a strategy with totalSupply = 0
        // will not respect the current collateral ratio of the strategy, it just uses the target collateral ratio
        require(
            beforeSharesTotalSupply != 0, "Shares total supply must be non-zero to use _testDeposit helper function"
        );

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(
            strategy, address(this), collateralToAdd, debtToBorrow, equityToAddInCollateralAsset, shares, sharesFee
        );
        (uint256 collateralAdded, uint256 debtBorrowed, uint256 sharesReceived, uint256 shareFeeCharged) =
            leverageManager.deposit(strategy, equityToAddInCollateralAsset, shares);

        assertEq(sharesReceived, shares);
        assertEq(strategy.balanceOf(address(this)), sharesReceived, "Shares received mismatch");
        assertEq(shareFeeCharged, sharesFee, "Share fee charged mismatch");

        StrategyState memory afterState = leverageManager.getStrategyState(strategy);
        assertEq(
            afterState.collateralInDebtAsset,
            beforeState.collateralInDebtAsset + lendingAdapter.convertCollateralToDebtAsset(collateralToAdd),
            "Collateral in strategy after deposit mismatch"
        );
        assertEq(collateralAdded, collateralToAdd, "Collateral added mismatch");
        assertEq(afterState.debt, beforeState.debt + debtToBorrow, "Debt in strategy after deposit mismatch");
        assertEq(debtBorrowed, debtToBorrow, "Debt borrowed mismatch");
        assertEq(debtToken.balanceOf(address(this)), debtToBorrow, "Debt tokens received mismatch");

        if (beforeState.collateralRatio == type(uint256).max) {
            assertLe(afterState.collateralRatio, beforeState.collateralRatio);
        } else {
            assertApproxEqRel(
                afterState.collateralRatio,
                beforeState.collateralRatio,
                collateralRatioDeltaRelative,
                "Collateral ratio after deposit mismatch"
            );
            assertGe(
                afterState.collateralRatio,
                beforeState.collateralRatio,
                "Collateral ratio after deposit should be greater than or equal to before"
            );
        }
    }
}
