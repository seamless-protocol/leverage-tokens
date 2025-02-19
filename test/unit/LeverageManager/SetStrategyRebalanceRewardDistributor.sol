// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract SetStrategyRebalanceRewardDistributor is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceRewardDistributor(IRebalanceRewardDistributor distributor) public {
        _setStrategyRebalanceRewardDistributor(manager, distributor);
        assertEq(address(leverageManager.getStrategyRebalanceRewardDistributor(strategy)), address(distributor));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceRewardDistributor_RevertIf_CallerIsNotManager(
        address caller,
        IRebalanceRewardDistributor distributor
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyRebalanceRewardDistributor(caller, distributor);
    }
}
