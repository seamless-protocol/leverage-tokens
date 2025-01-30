// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "test/unit/LeverageManager/LeverageManagerBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";

contract DepositTest is LeverageManagerBaseTest {
    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public override {
        super.setUp();

        MockLendingAdapter _lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(_lendingAdapter)),
                minCollateralRatio: _BASE_RATIO(),
                maxCollateralRatio: _BASE_RATIO() + 2,
                targetCollateralRatio: _BASE_RATIO() + 1,
                collateralCap: type(uint256).max
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    function test_deposit_EnoughCollateralDeficit() external {
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 1500 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 10 ether, // Not important for this test
            totalShares: 100 ether
        });

        uint256 equityInCollateralAsset = 100 ether;

        _test_deposit(state, equityInCollateralAsset);
    }

    function test_deposit_NotEnoughCollateralDeficit() external {
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 1500 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether, // Not important for this test
            totalShares: 100 ether
        });

        // 1000 ether of equity, so the deficit is not enough for full optimization
        uint128 equityInCollateralAsset = 1000 ether;

        _test_deposit(state, equityInCollateralAsset);
    }

    function test_deposit_StrategyIsOverCollateralized() external {
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 2500 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether, // Not important for this test
            totalShares: 100 ether
        });

        uint128 equityInCollateralAsset = 80 ether; // No optimization is possible here

        _test_deposit(state, equityInCollateralAsset);
    }

    function testFuzz_deposit(MintRedeemState memory state, uint128 equityInCollateralAsset) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _test_deposit(state, equityInCollateralAsset);
    }

    function testFuzz_deposit_SlippageTooHigh(MintRedeemState memory state, uint128 equityInCollateralAsset) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _mockState_MintRedeem(state);

        // Mock conversion of equity in collateral asset to equity in debt asset to be equal for simplicity
        _mockConvertCollateral(equityInCollateralAsset, equityInCollateralAsset);

        (uint256 expectedShares,,) = leverageManager.previewDeposit(strategy, equityInCollateralAsset);

        vm.assume(expectedShares > 0);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, expectedShares, expectedShares + 1)
        );
        leverageManager.deposit(strategy, equityInCollateralAsset, expectedShares + 1);
    }

    function _test_deposit(MintRedeemState memory state, uint256 equityInCollateralAsset) internal {
        _mockState_MintRedeem(state);

        (uint256 sharesToMint, uint256 collateral, uint256 debtToCoverEquity) =
            leverageManager.previewDeposit(strategy, equityInCollateralAsset);

        collateralToken.mint(address(this), collateral);
        collateralToken.approve(address(leverageManager), collateral);

        uint256 sharesReceived = leverageManager.deposit(strategy, equityInCollateralAsset, sharesToMint);

        assertEq(collateralToken.balanceOf(address(this)), 0);
        assertEq(sharesReceived, sharesToMint);
        assertEq(IERC20(strategy).balanceOf(address(this)), state.userShares + sharesReceived);
        assertEq(IERC20(strategy).totalSupply(), state.totalShares + sharesReceived);
        assertEq(debtToken.balanceOf(address(this)), debtToCoverEquity);
    }
}
