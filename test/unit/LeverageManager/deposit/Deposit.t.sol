// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract LeverageManagerDepositTest is LeverageManagerBaseTest {
    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public override {
        super.setUp();

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                collateralAsset: address(collateralToken),
                debtAsset: address(debtToken),
                lendingAdapter: ILendingAdapter(makeAddr("lendingAdapter")),
                minCollateralRatio: 0,
                maxCollateralRatio: 0,
                targetCollateralRatio: 0,
                collateralCap: type(uint256).max
            })
        );
    }

    function test_deposit() public {
        address recipient = makeAddr("recipient");

        uint256 targetRatio = 2 * _BASE_RATIO();
        uint128 strategyCollateral = 1 ether;
        uint128 amount = 1 ether;
        uint128 amountToDebtAsset = 3000 ether;

        _mockState_CalculateDebtAndShares(
            CalculateDebtAndSharesState({
                targetRatio: targetRatio,
                strategyCollateral: strategyCollateral,
                depositAmount: amount,
                depositAmountInDebtAsset: amountToDebtAsset,
                totalEquity: 0,
                strategyTotalShares: 0
            })
        );

        (uint256 expectedCollateral, uint256 expectedDebt, uint256 expectedShares) =
            leverageManager.exposed_calculateCollateralDebtAndShares(strategy, _getLendingAdapter(), amount);

        debtToken.mint(address(leverageManager), expectedDebt);
        collateralToken.mint(address(this), expectedCollateral);

        collateralToken.approve(address(leverageManager), expectedCollateral);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(strategy, address(this), recipient, amount, expectedShares);

        uint256 returnValue = leverageManager.deposit(strategy, amount, recipient, 0);

        assertEq(collateralToken.balanceOf(recipient), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), expectedCollateral);

        assertEq(debtToken.balanceOf(address(this)), expectedDebt);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);

        assertEq(returnValue, expectedShares);
    }

    function testFuzz_deposit(CalculateDebtAndSharesState memory state, address recipient) public {
        state.targetRatio = bound(state.targetRatio, _BASE_RATIO() + 1, 200 * _BASE_RATIO());
        _mockState_CalculateDebtAndShares(state);

        (uint256 expectedCollateral, uint256 expectedDebt, uint256 sharesBeforeFee) = leverageManager
            .exposed_calculateCollateralDebtAndShares(strategy, _getLendingAdapter(), state.depositAmount);
        uint256 expectedSharesToReceive =
            leverageManager.exposed_chargeStrategyFee(strategy, sharesBeforeFee, IFeeManager.Action.Deposit);

        collateralToken.mint(address(this), expectedCollateral);
        debtToken.mint(address(leverageManager), expectedDebt);

        collateralToken.approve(address(leverageManager), expectedCollateral);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(strategy, address(this), recipient, state.depositAmount, expectedSharesToReceive);

        uint256 returnValue = leverageManager.deposit(strategy, state.depositAmount, recipient, 0);

        assertEq(collateralToken.balanceOf(recipient), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), expectedCollateral);

        assertEq(debtToken.balanceOf(address(this)), expectedDebt);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);

        assertEq(returnValue, expectedSharesToReceive);
    }

    function testFuzz_deposit_RevertIf_CollateralExceedsCap(CalculateDebtAndSharesState memory state, uint256 cap)
        public
    {
        state.targetRatio = bound(state.targetRatio, _BASE_RATIO() + 1, 200 * _BASE_RATIO());

        _setStrategyCollateralCap(manager, cap);
        _mockState_CalculateDebtAndShares(state);

        (uint256 expectedCollateral,,) = leverageManager.exposed_calculateCollateralDebtAndShares(
            strategy, _getLendingAdapter(), state.depositAmount
        );

        uint256 collateralAfterDeposit = uint256(expectedCollateral) + state.strategyCollateral;
        vm.assume(collateralAfterDeposit > cap);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.CollateralExceedsCap.selector, collateralAfterDeposit, cap)
        );
        leverageManager.deposit(strategy, state.depositAmount, address(this), 0);
    }
}
