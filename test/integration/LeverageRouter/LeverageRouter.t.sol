// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

contract LeverageRouterTest is IntegrationTestBase {
    ILeverageRouter public leverageRouter;

    function setUp() public virtual override {
        super.setUp();

        leverageRouter = new LeverageRouter(leverageManager, MORPHO, swapAdapter);

        vm.label(address(leverageRouter), "leverageRouter");
        vm.label(address(swapAdapter), "swapAdapter");
    }

    function testFork_setUp() public view virtual override {
        assertEq(address(leverageManager.getLeverageTokenCollateralAsset(leverageToken)), address(WETH));
        assertEq(address(leverageManager.getLeverageTokenDebtAsset(leverageToken)), address(USDC));

        assertEq(address(leverageRouter.leverageManager()), address(leverageManager));
        assertEq(address(leverageRouter.morpho()), address(MORPHO));
        assertEq(address(leverageRouter.swapper()), address(swapAdapter));
    }

    function _dealAndDeposit(
        IERC20 collateralAsset,
        IERC20 debtAsset,
        uint256 dealAmount,
        uint256 collateralFromSender,
        uint256 debt,
        uint256 minShares,
        ISwapAdapter.SwapContext memory swapContext
    ) internal {
        deal(address(collateralAsset), user, dealAmount);

        vm.startPrank(user);
        collateralAsset.approve(address(leverageRouter), collateralFromSender);
        leverageRouter.deposit(leverageToken, collateralFromSender, debt, minShares, swapContext);
        vm.stopPrank();

        // No leftover assets in the LeverageRouter or the SwapAdapter
        assertEq(collateralAsset.balanceOf(address(leverageRouter)), 0);
        assertEq(collateralAsset.balanceOf(address(swapAdapter)), 0);
        assertEq(debtAsset.balanceOf(address(leverageRouter)), 0);
        assertEq(debtAsset.balanceOf(address(swapAdapter)), 0);
    }
}
