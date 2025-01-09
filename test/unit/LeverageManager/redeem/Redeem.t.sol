// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

contract RedeemTest is LeverageManagerBaseTest {
    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public override {
        super.setUp();

        MockLendingAdapter lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                collateralAsset: address(collateralToken),
                debtAsset: address(debtToken),
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: _BASE_RATIO(),
                maxCollateralRatio: _BASE_RATIO() + 2,
                targetCollateralRatio: _BASE_RATIO() + 1,
                collateralCap: type(uint256).max
            })
        );
    }

    function test_Redeem_EnoughExcess() external {
        RedeemState memory state = RedeemState({
            collateralInDebt: 3000 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 10 ether,
            totalShares: 100 ether
        });

        uint128 sharesToRedeem = 5 ether;

        _test_Redeem(state, sharesToRedeem);
    }

    function test_Redeem_NotEnoughExcess_ExcessExists() external {
        RedeemState memory state = RedeemState({
            collateralInDebt: 3000 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether,
            totalShares: 100 ether
        });

        uint128 sharesToRedeem = 80 ether;

        _test_Redeem(state, sharesToRedeem);
    }

    function test_Redeem_NotEnoughExcess_ExcessDoesNotExists() external {
        RedeemState memory state = RedeemState({
            collateralInDebt: 1600 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether,
            totalShares: 100 ether
        });

        uint128 sharesToRedeem = 80 ether;

        _test_Redeem(state, sharesToRedeem);
    }

    function testFuzz_Redeem(RedeemState memory state, uint256 sharesToRedeem) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.userShares > sharesToRedeem);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _test_Redeem(state, sharesToRedeem);
    }

    function testFuzz_Redeem_InsufficientAssets(RedeemState memory state, uint256 sharesToRedeem) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.userShares > sharesToRedeem);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _mockState_Redeem(state);

        uint256 sharesAfterFee =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, sharesToRedeem, IFeeManager.Action.Redeem);
        uint256 expectedEquity = leverageManager.exposed_convertToEquity(strategy, sharesAfterFee);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.InsufficientAssets.selector, expectedEquity, expectedEquity + 1)
        );
        leverageManager.redeem(strategy, sharesToRedeem, expectedEquity + 1);
    }

    function test_Redeem_RevertIf_InsufficientBalance(uint256 userShares, uint256 sharesToRedeem) external {
        vm.assume(userShares < sharesToRedeem);

        _mintShares(address(this), userShares);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.InsufficientBalance.selector, sharesToRedeem, userShares)
        );
        leverageManager.redeem(strategy, sharesToRedeem, 0);
    }

    function _test_Redeem(RedeemState memory state, uint256 sharesToRedeem) internal {
        _mockState_Redeem(state);

        uint256 sharesAfterFee =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, sharesToRedeem, IFeeManager.Action.Redeem);
        uint256 expectedEquity = leverageManager.exposed_convertToEquity(strategy, sharesAfterFee);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(strategy, _getLendingAdapter(), expectedEquity);

        debtToken.mint(address(this), debtToCoverEquity);
        debtToken.approve(address(leverageManager), debtToCoverEquity);

        leverageManager.redeem(strategy, sharesToRedeem, 0);

        assertEq(collateralToken.balanceOf(address(this)), collateral);
        assertEq(leverageManager.getUserStrategyShares(strategy, address(this)), state.userShares - sharesToRedeem);
        assertEq(leverageManager.getTotalStrategyShares(strategy), state.totalShares - sharesToRedeem);
        assertEq(debtToken.balanceOf(address(_getLendingAdapter())), debtToCoverEquity);
    }
}
