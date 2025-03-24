// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Internal imports
import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";
import {SeamlessRebalanceModuleHarness} from "./harness/SeamlessRebalanceModuleHarness.sol";
import {SeamlessRebalanceModule} from "src/rebalance/SeamlessRebalanceModule.sol";

contract InitializeTest is SeamlessRebalanceModuleBaseTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_initialize(address initialOwner) public {
        address rebalanceModuleImplementation = address(new SeamlessRebalanceModuleHarness());
        address rebalanceModuleProxy = UnsafeUpgrades.deployUUPSProxy(
            rebalanceModuleImplementation,
            abi.encodeWithSelector(SeamlessRebalanceModule.initialize.selector, initialOwner)
        );
        SeamlessRebalanceModuleHarness newModule = SeamlessRebalanceModuleHarness(rebalanceModuleProxy);

        assertEq(newModule.owner(), initialOwner);
    }

    function test_initialize_RevertIf_AlreadyInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rebalanceModule.initialize(defaultAdmin);
    }
}
