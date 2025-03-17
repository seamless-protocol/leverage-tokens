// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.26;

// // Dependency imports
// import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// // Internal imports
// import {Strategy} from "src/Strategy.sol";
// import {StrategyBaseTest} from "./StrategyBase.t.sol";

// contract StrategyBeaconUpgradeToTest is StrategyBaseTest {
//     address public upgrader = makeAddr("upgrader");
//     UpgradeableBeacon public beacon;

//     function setUp() public override {
//         super.setUp();
//         address strategyTokenImplementation = address(new Strategy());
//         beacon = new UpgradeableBeacon(strategyTokenImplementation, upgrader);
//         address strategyTokenProxy = address(
//             new BeaconProxy(
//                 address(beacon),
//                 abi.encodeWithSelector(Strategy.initialize.selector, address(this), "Test name", "Test symbol")
//             )
//         );
//         strategyToken = Strategy(strategyTokenProxy);
//     }

//     function test_upgradeTo() public {
//         // Deploy new implementation
//         Strategy newImplementation = new Strategy();

//         // Expect the Upgraded event to be emitted
//         vm.expectEmit(true, true, true, true);
//         emit UpgradeableBeacon.Upgraded(address(newImplementation));

//         beacon.upgradeTo(address(newImplementation));
//     }

//     /// forge-config: default.fuzz.runs = 1
//     function testFuzz_upgradeTo_RevertIf_NonUpgraderUpgrades(address nonUpgrader) public {
//         vm.assume(nonUpgrader != upgrader);

//         Strategy newImplementation = new Strategy();

//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonUpgrader));
//         vm.prank(nonUpgrader);
//         beacon.upgradeTo(address(newImplementation));
//     }
// }
