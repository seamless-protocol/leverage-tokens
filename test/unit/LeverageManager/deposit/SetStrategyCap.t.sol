// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract setStrategyCollateralCapTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyCollateralCap(address strategy, uint256 cap) public {
        _setStrategyCollateralCap(manager, strategy, cap);
        assertEq(leverageManager.getStrategyCollateralCap(strategy), cap);
    }

    // If caller is not the manager, then the transaction should revert
    function testFuzz_setStrategyCollateralCap_RevertIf_CallerIsNotManager(
        address caller,
        address strategy,
        uint256 cap
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyCollateralCap(caller, strategy, cap);
    }
}
