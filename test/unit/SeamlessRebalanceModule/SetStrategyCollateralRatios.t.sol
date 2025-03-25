// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";
import {ISeamlessRebalanceModule} from "src/interfaces/ISeamlessRebalanceModule.sol";

contract SetLeverageTokenCollateralRatiosTest is SeamlessRebalanceModuleBaseTest {
    function test_setLeverageTokenCollateralRatios() public {
        uint256 minCollateralRatio = 150_00; // 1.5x
        uint256 maxCollateralRatio = 250_00; // 2.5x

        vm.prank(defaultAdmin);
        rebalanceModule.setLeverageTokenCollateralRatios(leverageToken, minCollateralRatio, maxCollateralRatio);

        assertEq(rebalanceModule.getLeverageTokenMinCollateralRatio(leverageToken), minCollateralRatio);
        assertEq(rebalanceModule.getLeverageTokenMaxCollateralRatio(leverageToken), maxCollateralRatio);
    }

    function testFuzz_setLeverageTokenCollateralRatios_RevertIf_NotOwner(
        address caller,
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) public {
        vm.assume(caller != defaultAdmin);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        rebalanceModule.setLeverageTokenCollateralRatios(leverageToken, minCollateralRatio, maxCollateralRatio);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setLeverageTokenCollateralRatios_RevertIf_CollateralRatiosAlreadySet(
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) public {
        minCollateralRatio = bound(minCollateralRatio, 0, maxCollateralRatio);
        vm.assume(minCollateralRatio != 0 || maxCollateralRatio != 0);

        vm.startPrank(defaultAdmin);
        rebalanceModule.setLeverageTokenCollateralRatios(leverageToken, minCollateralRatio, maxCollateralRatio);

        vm.expectRevert(ISeamlessRebalanceModule.CollateralRatiosAlreadySet.selector);
        rebalanceModule.setLeverageTokenCollateralRatios(leverageToken, minCollateralRatio, maxCollateralRatio);
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setLeverageTokenCollateralRatios_RevertIf_MinCollateralRatioTooHigh(
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) public {
        vm.startPrank(defaultAdmin);
        maxCollateralRatio = bound(maxCollateralRatio, 0, type(uint256).max - 1);
        minCollateralRatio = bound(minCollateralRatio, maxCollateralRatio + 1, type(uint256).max);

        vm.expectRevert(ISeamlessRebalanceModule.MinCollateralRatioTooHigh.selector);
        rebalanceModule.setLeverageTokenCollateralRatios(leverageToken, minCollateralRatio, maxCollateralRatio);
        vm.stopPrank();
    }
}
