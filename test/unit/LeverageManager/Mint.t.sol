// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerBaseTest} from "test/unit/LeverageManager/LeverageManagerBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

contract MintTest is LeverageManagerBaseTest {
    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public override {
        super.setUp();

        MockLendingAdapter lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
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

    function test_mint_EnoughCollateralDeficit() external {
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 1500 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 10 ether, // Not important for this test
            totalShares: 100 ether
        });

        uint128 sharesToMint = 100 ether;

        (uint256 collateral, uint256 debt) = _test_mint(state, sharesToMint);

        // Optimized
        assertEq(collateral, 499999999999999999996);
        assertEq(debt, 0);
    }

    function test_mint_NotEnoughCollateralDeficit() external {
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 1500 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether, // Not important for this test
            totalShares: 100 ether
        });

        uint128 sharesToMint = 200 ether; // This equals to around 1000 ether of equity so deficit is not enough for full optimization

        (uint256 collateral, uint256 debt) = _test_mint(state, sharesToMint);

        // Partially optimized
        assertEq(collateral, 1499999999999999999984);
        assertEq(debt, 499999999999999999992);
    }

    function test_mint_StrategyIsOverCollateralized() external {
        MintRedeemState memory state = MintRedeemState({
            collateralInDebt: 2500 ether,
            debt: 1000 ether,
            targetRatio: uint128(2 * _BASE_RATIO()), // 2x leverage
            userShares: 90 ether, // Not important for this test
            totalShares: 100 ether
        });

        uint128 sharesToMint = 80 ether; // No optimization is possible here

        (uint256 collateral, uint256 debt) = _test_mint(state, sharesToMint);

        // Not optimized
        assertEq(collateral, 2399999999999999999976);
        assertEq(debt, 1199999999999999999988);
    }

    function testFuzz_mint(MintRedeemState memory state, uint128 sharesToMint) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _test_mint(state, sharesToMint);
    }

    function testFuzz_mint_SlippageTooHigh(MintRedeemState memory state, uint128 sharesToMint) external {
        vm.assume(state.totalShares > state.userShares);
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.collateralInDebt > state.debt);

        _mockState_MintRedeem(state);

        uint256 sharesAfterFee =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, sharesToMint, IFeeManager.Action.Deposit);
        uint256 expectedEquity = leverageManager.exposed_convertToEquity(strategy, sharesAfterFee);

        vm.assume(expectedEquity > 0);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, expectedEquity, expectedEquity - 1)
        );
        leverageManager.mint(strategy, sharesToMint, expectedEquity - 1);
    }

    function _test_mint(MintRedeemState memory state, uint256 sharesToMint)
        internal
        returns (uint256 collateral, uint256 debt)
    {
        _mockState_MintRedeem(state);

        (, uint256 requiredCollateral, uint256 debtToCoverEquity, uint256 expectedShares) =
            leverageManager.previewMint(strategy, sharesToMint);

        collateralToken.mint(address(this), requiredCollateral);
        collateralToken.approve(address(leverageManager), requiredCollateral);

        leverageManager.mint(strategy, sharesToMint, type(uint256).max);

        assertEq(collateralToken.balanceOf(address(this)), 0);
        assertEq(IERC20(strategy).balanceOf(address(this)), state.userShares + expectedShares);
        assertEq(IERC20(strategy).totalSupply(), state.totalShares + expectedShares);
        assertEq(debtToken.balanceOf(address(this)), debtToCoverEquity);

        return (requiredCollateral, debtToCoverEquity);
    }
}
