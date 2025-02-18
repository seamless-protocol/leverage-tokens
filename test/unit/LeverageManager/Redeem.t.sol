// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerBaseTest} from "test/unit/LeverageManager/LeverageManagerBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

contract RedeemTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: _BASE_RATIO(),
                maxCollateralRatio: _BASE_RATIO() + 2,
                targetCollateralRatio: _BASE_RATIO() + 1,
                collateralCap: type(uint256).max,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    function test_Redeem_EnoughExcess() external {
        MintRedeemState memory state = MintRedeemState({
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
        MintRedeemState memory state = MintRedeemState({
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
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 1600 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether,
            totalShares: 100 ether
        });

        uint128 sharesToRedeem = 80 ether;

        _test_Redeem(state, sharesToRedeem);
    }

    function testFuzz_Redeem(MintRedeemState memory state, uint256 sharesToRedeem) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.userShares > sharesToRedeem);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > uint256(state.debt) * 1005 / 1000); // Realistic assumption that excess is at least 0.5%

        _test_Redeem(state, sharesToRedeem);
    }

    function testFuzz_Redeem_SlippageTooHigh(MintRedeemState memory state, uint256 sharesToRedeem) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.userShares > sharesToRedeem);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _mockState_MintRedeem(state);

        uint256 sharesAfterFee =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, sharesToRedeem, IFeeManager.Action.Redeem);
        uint256 expectedEquity = leverageManager.exposed_convertToEquity(strategy, sharesAfterFee);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, expectedEquity, expectedEquity + 1)
        );
        leverageManager.redeem(strategy, sharesToRedeem, expectedEquity + 1);
    }

    function _test_Redeem(MintRedeemState memory state, uint256 sharesToRedeem) internal {
        _mockState_MintRedeem(state);

        uint256 sharesAfterFee =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, sharesToRedeem, IFeeManager.Action.Redeem);
        uint256 expectedEquity = leverageManager.exposed_convertToEquity(strategy, sharesAfterFee);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), expectedEquity, IFeeManager.Action.Redeem
        );

        debtToken.mint(address(this), debtToCoverEquity);
        debtToken.approve(address(leverageManager), debtToCoverEquity);
        collateralToken.mint(address(lendingAdapter), collateral);

        leverageManager.redeem(strategy, sharesToRedeem, 0);

        assertEq(collateralToken.balanceOf(address(this)), collateral);
        assertEq(IERC20(strategy).balanceOf(address(this)), state.userShares - sharesToRedeem);
        assertEq(IERC20(strategy).totalSupply(), state.totalShares - sharesToRedeem);
        assertEq(debtToken.balanceOf(address(_getLendingAdapter())), debtToCoverEquity);
    }
}
