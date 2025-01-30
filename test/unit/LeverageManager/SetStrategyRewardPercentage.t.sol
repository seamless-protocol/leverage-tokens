// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract SetStrategyRewardPercentage is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceReward(uint256 percentage) public {
        vm.assume(percentage <= leverageManager.BASE_REWARD_PERCENTAGE());

        _setStrategyRebalanceReward(manager, percentage);
        assertEq(leverageManager.getStrategyRebalanceReward(strategy), percentage);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceReward_RevertIf_InvalidPercentage(address caller, uint256 reward) public {
        vm.assume(reward > leverageManager.BASE_REWARD_PERCENTAGE());

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.InvalidRewardPercentage.selector, reward));
        _setStrategyRebalanceReward(manager, reward);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceReward_RevertIf_CallerIsNotManager(address caller, uint256 reward) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyRebalanceReward(caller, reward);
    }
}
