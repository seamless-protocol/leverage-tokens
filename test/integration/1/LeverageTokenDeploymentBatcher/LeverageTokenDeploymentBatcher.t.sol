// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageTokenDeploymentBatcher} from "src/periphery/LeverageTokenDeploymentBatcher.sol";
import {ILeverageTokenDeploymentBatcher} from "src/interfaces/periphery/ILeverageTokenDeploymentBatcher.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

contract LeverageTokenDeploymentBatcherTest is IntegrationTestBase {
    ILeverageTokenDeploymentBatcher public leverageTokenDeploymentBatcher;

    function setUp() public virtual override {
        super.setUp();

        leverageTokenDeploymentBatcher =
            new LeverageTokenDeploymentBatcher(leverageManager, morphoLendingAdapterFactory);

        vm.label(address(leverageTokenDeploymentBatcher), "leverageTokenDeploymentBatcher");
    }

    function testFork_setUp() public view virtual override {
        assertEq(address(leverageTokenDeploymentBatcher.leverageManager()), address(leverageManager));
        assertEq(
            address(leverageTokenDeploymentBatcher.morphoLendingAdapterFactory()), address(morphoLendingAdapterFactory)
        );
    }
}
