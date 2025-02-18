// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IRebalanceProfitDistributor} from "src/interfaces/IRebalanceProfitDistributor.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract SetStrategyRebalanceProfitDistributor is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceProfitDistributor(IRebalanceProfitDistributor distributor) public {
        _setStrategyRebalanceProfitDistributor(manager, distributor);
        assertEq(address(leverageManager.getStrategyRebalanceProfitDistributor(strategy)), address(distributor));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceProfitDistributor_RevertIf_CallerIsNotManager(
        address caller,
        IRebalanceProfitDistributor distributor
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyRebalanceProfitDistributor(caller, distributor);
    }
}
