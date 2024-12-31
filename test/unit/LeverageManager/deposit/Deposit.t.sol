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

        uint128 amount = 1 ether;
        collateralToken.mint(address(this), amount);

        uint256 targetRatio = 2 * _BASE_RATIO();
        uint128 amountToDebtAsset = 3000 ether;

        uint256 expectedSharesToReceive = 1500 ether;
        uint256 expectedDebtToReceive = 1500 ether;
        debtToken.mint(address(leverageManager), expectedDebtToReceive);

        _mockState_CalculateDebtAndShares(
            CalculateDebtAndSharesState({
                targetRatio: targetRatio,
                collateral: amount,
                convertedCollateral: amountToDebtAsset,
                totalEquity: 0,
                strategyTotalShares: 0
            })
        );

        collateralToken.approve(address(leverageManager), amount);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(strategy, address(this), recipient, amount, expectedSharesToReceive);

        uint256 returnValue = leverageManager.deposit(strategy, amount, recipient, 0);

        assertEq(collateralToken.balanceOf(recipient), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), amount);

        assertEq(debtToken.balanceOf(address(this)), expectedDebtToReceive);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);

        assertEq(returnValue, expectedSharesToReceive);
    }

    /*
    function testFuzz_deposit(CalculateDebtAndSharesState memory state, address recipient) public {
        state.targetRatio = bound(state.targetRatio, _BASE_RATIO(), 200 * _BASE_RATIO());
        _mockState_CalculateDebtAndShares(state);

        (uint256 expectedDebtToReceive, uint256 sharesBeforeFee) =
            leverageManager.exposed_calculateDebtAndShares(strategy, _getLendingAdapter(), state.collateral);
        uint256 expectedSharesToReceive =
            leverageManager.exposed_chargeStrategyFee(strategy, sharesBeforeFee, IFeeManager.Action.Deposit);

        collateralToken.mint(address(this), state.collateral);
        debtToken.mint(address(leverageManager), expectedDebtToReceive);

        collateralToken.approve(address(leverageManager), state.collateral);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(strategy, address(this), recipient, state.collateral, expectedSharesToReceive);

        uint256 returnValue = leverageManager.deposit(strategy, state.collateral, recipient, 0);

        assertEq(collateralToken.balanceOf(recipient), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), state.collateral);

        assertEq(debtToken.balanceOf(address(this)), expectedDebtToReceive);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);

        assertEq(returnValue, expectedSharesToReceive);
    }
    */

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_CollateralExceedsCap(uint128 amount, uint128 currentCollateral, uint256 cap)
        public
    {
        uint256 collateralAfterDeposit = uint256(amount) + currentCollateral;
        vm.assume(collateralAfterDeposit > cap);

        _setStrategyCollateralCap(manager, cap);
        _mockStrategyCollateral(currentCollateral);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.CollateralExceedsCap.selector, collateralAfterDeposit, cap)
        );
        leverageManager.deposit(strategy, amount, address(this), 0);
    }
}
