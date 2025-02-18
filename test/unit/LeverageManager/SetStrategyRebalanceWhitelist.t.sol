// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract SetStrategyRebalanceWhitelistTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceWhitelist(IRebalanceWhitelist whitelistModule) public {
        _setStrategyRebalanceWhitelist(manager, whitelistModule);
        assertEq(address(leverageManager.getStrategyRebalanceWhitelist(strategy)), address(whitelistModule));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyRebalanceWhitelist_RevertIf_CallerIsNotManager(
        address caller,
        IRebalanceWhitelist whitelist
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );

        _setStrategyRebalanceWhitelist(caller, whitelist);
    }
}
