// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract LeverageManagerDepositTest is LeverageManagerBaseTest {
    address public strategy = makeAddr("strategy");
    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public override {
        super.setUp();

        vm.prank(manager);
        leverageManager.setStrategyCore(
            strategy, Storage.StrategyCore({collateral: address(collateralToken), debt: address(debtToken)})
        );
    }

    function test_deposit() public {
        uint128 amount = 1 ether;
        collateralToken.mint(address(this), amount);

        uint256 targetRatio = 2 * BASE_RATIO;
        uint128 amountToDebtAsset = 3000 ether;

        uint256 expectedDebtToReceive = 1500 ether;
        debtToken.mint(address(leverageManager), expectedDebtToReceive);

        _mockState_CalculateDebtAndShares(
            CalculateDebtAndSharesState({
                strategy: strategy,
                targetRatio: targetRatio,
                collateral: amount,
                convertedCollateral: amountToDebtAsset,
                totalEquity: 0,
                strategyTotalShares: 0
            })
        );

        _mockStrategyTargetRatio(strategy, targetRatio);

        collateralToken.approve(address(leverageManager), amount);
        leverageManager.deposit(strategy, amount, address(this), 0);

        assertEq(collateralToken.balanceOf(address(this)), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), amount);
        assertEq(debtToken.balanceOf(address(this)), expectedDebtToReceive);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);
    }

    function testFuzz_deposit(CalculateDebtAndSharesState memory state) public {
        state.strategy = strategy;
        state.targetRatio = bound(state.targetRatio, BASE_RATIO, 200 * BASE_RATIO);
        _mockState_CalculateDebtAndShares(state);

        (uint256 expectedDebtToReceive,) = leverageManager.calculateDebtAndShares(
            state.strategy, leverageManager.getLendingContract(), state.collateral
        );

        collateralToken.mint(address(this), state.collateral);
        debtToken.mint(address(leverageManager), expectedDebtToReceive);

        collateralToken.approve(address(leverageManager), state.collateral);
        leverageManager.deposit(state.strategy, state.collateral, address(this), 0);

        assertEq(collateralToken.balanceOf(address(this)), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), state.collateral);
        assertEq(debtToken.balanceOf(address(this)), expectedDebtToReceive);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);
    }
}
