// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

contract LeverageRouterTest is IntegrationTestBase {
    address public constant UNISWAP_V2_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    ILeverageRouter public leverageRouter;

    function setUp() public virtual override {
        super.setUp();

        leverageRouter = new LeverageRouter(leverageManager, MORPHO);

        vm.label(address(leverageRouter), "leverageRouter");
    }

    function testFork_setUp() public view virtual override {
        assertEq(address(leverageManager.getLeverageTokenCollateralAsset(leverageToken)), address(CBBTC));
        assertEq(address(leverageManager.getLeverageTokenDebtAsset(leverageToken)), address(USDC));

        assertEq(address(leverageRouter.leverageManager()), address(leverageManager));
        assertEq(address(leverageRouter.morpho()), address(MORPHO));
    }

    function _dealAndDeposit(
        IERC20 collateralAsset,
        IERC20 debtAsset,
        uint256 dealAmount,
        uint256 collateralFromSender,
        uint256 flashLoanAmount,
        uint256 minShares,
        ILeverageRouter.Call[] memory calls
    ) internal {
        deal(address(collateralAsset), user, dealAmount);

        vm.startPrank(user);
        collateralAsset.approve(address(leverageRouter), collateralFromSender);
        leverageRouter.deposit(leverageToken, collateralFromSender, flashLoanAmount, minShares, calls);
        vm.stopPrank();

        // No leftover assets in the LeverageRouter
        assertEq(collateralAsset.balanceOf(address(leverageRouter)), 0, "no collateral left in LeverageRouter");
        assertEq(debtAsset.balanceOf(address(leverageRouter)), 0, "no debt left in LeverageRouter");
    }

    function _deployLeverageRouterIntegrationTestContracts() internal {
        _deployIntegrationTestContracts();

        leverageRouter = new LeverageRouter(leverageManager, MORPHO);

        vm.label(address(leverageRouter), "leverageRouter");
    }
}
