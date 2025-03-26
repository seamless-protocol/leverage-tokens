// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {MockLeverageManager} from "test/unit/mock/MockLeverageManager.sol";
import {MinMaxCollateralRatioRebalanceAdapter} from "src/rebalance/MinMaxCollateralRatioRebalanceAdapter.sol";
import {MinMaxCollateralRatioRebalanceAdapterHarness} from
    "test/unit/harness/MinMaxCollateralRatioRebalanceAdapterHarness.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract MinMaxCollateralRatioRebalanceAdapterTest is Test {
    uint256 public constant TARGET_RATIO = 2e8; // 2x

    ILeverageToken public leverageToken = ILeverageToken(makeAddr("leverageToken"));

    MockLeverageManager public leverageManager;
    MinMaxCollateralRatioRebalanceAdapterHarness public rebalanceModule;

    function setUp() public virtual {
        address rebalanceModuleImplementation = address(new MinMaxCollateralRatioRebalanceAdapterHarness());
        address rebalanceModuleProxy = UnsafeUpgrades.deployUUPSProxy(
            rebalanceModuleImplementation,
            abi.encodeWithSelector(
                MinMaxCollateralRatioRebalanceAdapterHarness.initialize.selector, 1.5 * 1e8, 2.5 * 1e8
            )
        );
        rebalanceModule = MinMaxCollateralRatioRebalanceAdapterHarness(rebalanceModuleProxy);
        leverageManager = new MockLeverageManager();
    }

    function test_setUp() public virtual {
        bytes32 expectedSlot = keccak256(
            abi.encode(uint256(keccak256("seamless.contracts.storage.MinMaxCollateralRatioRebalanceAdapter")) - 1)
        ) & ~bytes32(uint256(0xff));
        assertEq(rebalanceModule.exposed_getMinMaxCollateralRatioRebalanceAdapterStorage(), expectedSlot);
    }

    function _mockCollateralRatio(uint256 collateralRatio) internal {
        leverageManager.setLeverageTokenState(
            leverageToken,
            LeverageTokenState({collateralInDebtAsset: 0, debt: 0, equity: 0, collateralRatio: collateralRatio})
        );
    }
}
