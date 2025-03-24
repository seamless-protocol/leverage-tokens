// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
import {SeamlessRebalanceModule} from "src/rebalance/SeamlessRebalanceModule.sol";
import {SeamlessRebalanceModuleHarness} from "./harness/SeamlessRebalanceModuleHarness.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract SeamlessRebalanceModuleBaseTest is Test {
    uint256 public constant TARGET_RATIO = 2e8; // 2x

    IStrategy public strategy = IStrategy(makeAddr("strategy"));
    address public defaultAdmin = makeAddr("defaultAdmin");

    MockLeverageManager public leverageManager;
    SeamlessRebalanceModuleHarness public rebalanceModule;

    function setUp() public virtual {
        address rebalanceModuleImplementation = address(new SeamlessRebalanceModuleHarness());
        address rebalanceModuleProxy = UnsafeUpgrades.deployUUPSProxy(
            rebalanceModuleImplementation,
            abi.encodeWithSelector(SeamlessRebalanceModule.initialize.selector, defaultAdmin)
        );
        rebalanceModule = SeamlessRebalanceModuleHarness(rebalanceModuleProxy);
        leverageManager = new MockLeverageManager();
    }

    function test_setUp() public virtual {
        bytes32 expectedSlot = keccak256(
            abi.encode(uint256(keccak256("seamless.contracts.storage.SeamlessRebalanceModule")) - 1)
        ) & ~bytes32(uint256(0xff));
        assertEq(rebalanceModule.exposed_getSeamlessRebalanceModuleStorage(), expectedSlot);
        assertTrue(rebalanceModule.owner() == defaultAdmin);
    }

    function _mockCollateralRatio(uint256 collateralRatio) internal {
        leverageManager.setStrategyState(
            strategy, StrategyState({collateralInDebtAsset: 0, debt: 0, equity: 0, collateralRatio: collateralRatio})
        );
    }
}
