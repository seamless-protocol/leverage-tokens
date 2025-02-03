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

import {MockLendingAdapterRebalance} from "test/unit/mock/MockLendingAdapterRebalance.sol";

contract MintTest is LeverageManagerBaseTest {
    ERC20Mock public weth = new ERC20Mock();
    ERC20Mock public usdc = new ERC20Mock();

    MockLendingAdapterRebalance adapter;

    function setUp() public override {
        super.setUp();

        adapter = new MockLendingAdapterRebalance(address(weth), address(usdc));

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(adapter)),
                minCollateralRatio: _BASE_RATIO(),
                maxCollateralRatio: 3 * _BASE_RATIO(),
                targetCollateralRatio: 2 * _BASE_RATIO(), // 2x leverage
                collateralCap: type(uint256).max,
                rebalanceRewardPercentage: 0
            }),
            address(weth),
            address(usdc),
            "dummy name",
            "dummy symbol"
        );
    }

    function test_deposit_BringStrategyInBetterState_UnderCollateralized() external {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 6_000 ether; // 6,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2 ether; // 4,000 USDC
        uint256 debtToTake = 2_000 ether; // 2,000 USDC

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, 2000 ether);

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        // After this deposit strategy will have 12,000 USDC collateral and 6,000 USDC debt so action should pass properly
        uint256 returnValue = leverageManager.deposit(strategy, collateralToDeposit, debtToTake, expectedShares);

        assertEq(returnValue, expectedShares);
        assertEq(strategy.balanceOf(address(this)), expectedShares);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), debtToTake);
    }

    function test_deposit_BringStrategyInBetterState_OverCollateralized() external {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 4_000 ether; // 4,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2 ether; // 4,000 USDC
        uint256 debtToTake = 3_000 ether; // 3,000 USDC

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, 1000 ether);

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        // After this deposit strategy will have 12,000 USDC collateral and 6,000 USDC debt so action should pass properly
        uint256 returnValue = leverageManager.deposit(strategy, collateralToDeposit, debtToTake, expectedShares);

        assertEq(returnValue, expectedShares);
        assertEq(strategy.balanceOf(address(this)), expectedShares);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), debtToTake);
    }

    function test_deposit_FollowCurrentRatio_UnderCollateralized() public {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 6_000 ether; // 6,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2.5 ether; // 5,000 USDC
        uint256 debtToTake = 3_000 ether; // 3,000 USDC

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, 2000 ether);

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        // After this deposit strategy will have 12,000 USDC collateral and 6,000 USDC debt so action should pass properly
        uint256 returnValue = leverageManager.deposit(strategy, collateralToDeposit, debtToTake, expectedShares);

        assertEq(returnValue, expectedShares);
        assertEq(strategy.balanceOf(address(this)), expectedShares);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), debtToTake);
    }

    function test_deposit_FollowCurrentRatio_OverCollateralized() public {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 4_000 ether; // 4,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2.5 ether; // 5,000 USDC
        uint256 debtToTake = 2_000 ether; // 2,000 USDC

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, 3000 ether);

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        // After this deposit strategy will have 12,000 USDC collateral and 6,000 USDC debt so action should pass properly
        uint256 returnValue = leverageManager.deposit(strategy, collateralToDeposit, debtToTake, expectedShares);

        assertEq(returnValue, expectedShares);
        assertEq(strategy.balanceOf(address(this)), expectedShares);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(this)), debtToTake);
    }

    function test_deposit_RevertIf_WorseCollateralRatio_UnderCollateralized() external {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 6_000 ether; // 6,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2.5 ether; // 5,000 USDC
        uint256 debtToTake = 4_000 ether; // 4,000 USDC

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        vm.expectRevert(ILeverageManager.CollateralRatioInvalid.selector);
        leverageManager.deposit(strategy, collateralToDeposit, debtToTake, 0);
    }

    function test_deposit_RevertIf_CollateralRatioChangesSign_OverCollateralized() external {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 4_000 ether; // 4,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2.5 ether; // 5,000 USDC
        uint256 debtToTake = 4_000 ether; // 4,000 USDC

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        vm.expectRevert(ILeverageManager.ExposureDirectionChanged.selector);
        leverageManager.deposit(strategy, collateralToDeposit, debtToTake, 0);
    }

    function test_deposit_RevertIf_InsufficientShares() external {
        uint256 ethPrice = 2000_00000000; // 2000 USDC
        uint256 currentCollateral = 5 ether; // 10,000 USDC
        uint256 currentDebt = 4_000 ether; // 4,000 USDC

        _prepareStateForDeposit(currentCollateral, currentDebt, ethPrice);

        // Should allow to deposit collateral and to take debt it strategy goes towards better collateral ratio
        uint256 collateralToDeposit = 2.5 ether; // 5,000 USDC
        uint256 debtToTake = 2_000 ether; // 2,000 USDC

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, 3000 ether);

        weth.mint(address(this), collateralToDeposit);
        weth.approve(address(leverageManager), collateralToDeposit);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, expectedShares, expectedShares + 1)
        );
        leverageManager.deposit(strategy, collateralToDeposit, debtToTake, expectedShares + 1);
    }

    function _prepareStateForDeposit(uint256 collateral, uint256 debt, uint256 exchangeRate) internal {
        adapter.setCollateralToDebtExchangeRate(exchangeRate);
        adapter.mockCollateral(collateral);
        adapter.mockDebt(debt);
    }
}
