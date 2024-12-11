// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract RedeemTest is LeverageManagerBaseTest {
    address recipient = makeAddr("recipient");
    address public strategy = makeAddr("strategy");
    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public override {
        super.setUp();

        _setStrategyCore(
            manager, strategy, Storage.StrategyCore({collateral: address(collateralToken), debt: address(debtToken)})
        );
    }

    function test_redeem() public {
        RedeemState memory state = RedeemState({
            strategy: strategy,
            // Strategy fee is 10%
            fee: 10_00,
            // 3000 USDC worth collateral
            collateralInDebt: 3000 ether,
            // 1000 USDC debt
            debt: 1000 ether,
            // 2x leverage
            targetRatio: 2 * BASE_RATIO,
            // 300 total shares supply
            totalShares: 300 ether,
            // User poses 1/3 of a shares
            userShares: 100 ether
        });

        _mockState_Redeem(state);

        // User withdraws 50 shares which is 1/6 of total supply so he should receive 1/6 of equity
        uint128 amount = 50 ether;

        uint256 amountAfterFee = leverageManager.chargeStrategyFee(strategy, amount, IFeeManager.Action.Withdraw);
        uint256 expectedEquity = leverageManager.convertToEquity(strategy, amountAfterFee);
        uint256 expectedDebtToRepay =
            leverageManager.calculateDebtToCoverEquity(strategy, leverageManager.getLendingContract(), expectedEquity);

        // Simulate withdraw from lending contract
        debtToken.mint(address(this), expectedDebtToRepay);

        // Simulate conversion rate
        _mockConvertDebtToCollateralAsset(strategy, expectedDebtToRepay + expectedEquity, 900 ether);
        collateralToken.mint(address(leverageManager), 900 ether);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Redeem(strategy, address(this), recipient, amount, 900 ether);
        leverageManager.redeem(strategy, amount, recipient, 0);

        // Debt tokens are taken from user to cover the debt
        assertEq(debtToken.balanceOf(address(this)), 0);
        assertEq(debtToken.balanceOf(address(leverageManager)), expectedDebtToRepay);

        // Collateral tokens are sent to user
        assertEq(collateralToken.balanceOf(recipient), 900 ether);
        assertEq(collateralToken.balanceOf(address(leverageManager)), 0);

        // Shares are burned
        assertEq(leverageManager.getTotalStrategyShares(strategy), state.totalShares - amount);
        assertEq(leverageManager.getUserStrategyShares(strategy, address(this)), state.userShares - amount);
    }

    struct RedeemState {
        address strategy;
        uint128 fee;
        uint128 collateralInDebt;
        uint128 debt;
        uint256 targetRatio;
        uint128 totalShares;
        uint128 userShares;
    }

    function _mockState_Redeem(RedeemState memory state) internal {
        _mockState_CalculateExcessOfCollateral(
            CalculateExcessOfCollateralState({
                strategy: state.strategy,
                collateralInDebt: state.collateralInDebt,
                debt: state.debt,
                targetRatio: state.targetRatio
            })
        );

        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({
                strategy: state.strategy,
                totalEquity: state.collateralInDebt - state.debt,
                sharesTotalSupply: state.totalShares - state.userShares
            })
        );

        _mintShares(strategy, address(this), state.userShares);

        _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action.Withdraw, state.fee);
    }
}
