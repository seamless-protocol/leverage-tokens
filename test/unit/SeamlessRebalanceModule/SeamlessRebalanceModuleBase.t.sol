// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
import {SeamlessRebalanceModule} from "src/rebalance/SeamlessRebalanceModule.sol";
import {SeamlessRebalanceModuleHarness} from "./harness/SeamlessRebalanceModuleHarness.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract SeamlessRebalanceModuleBaseTest is Test {
    uint256 public constant TARGET_RATIO = 2e8; // 2x

    IStrategy public strategy = IStrategy(makeAddr("strategy"));
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public dutchAuctionModule = makeAddr("dutchAuctionModule");

    MockLeverageManager public leverageManager;
    SeamlessRebalanceModuleHarness public rebalanceModule;

    function setUp() public virtual {
        address rebalanceModuleImplementation = address(new SeamlessRebalanceModuleHarness());
        address rebalanceModuleProxy = UnsafeUpgrades.deployUUPSProxy(
            rebalanceModuleImplementation,
            abi.encodeWithSelector(SeamlessRebalanceModule.initialize.selector, defaultAdmin, dutchAuctionModule)
        );
        rebalanceModule = SeamlessRebalanceModuleHarness(rebalanceModuleProxy);
        leverageManager = new MockLeverageManager();
    }

    function test_setUp() public virtual {
        bytes32 expectedSlot = 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600;
        assertEq(rebalanceModule.exposed_getSeamlessRebalanceModuleStorage(), expectedSlot);
        assertEq(rebalanceModule.getDutchAuctionModule(), dutchAuctionModule);
        assertTrue(rebalanceModule.owner() == defaultAdmin);
    }

    function _mockCollateralRatio(uint256 collateralRatio) internal {
        leverageManager.setStrategyState(
            strategy, StrategyState({collateralInDebtAsset: 0, debt: 0, equity: 0, collateralRatio: collateralRatio})
        );
    }
}
