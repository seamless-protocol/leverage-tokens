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
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract MinMaxCollateralRatioRebalanceAdapterTest is Test {
    uint256 public constant TARGET_RATIO = 2e18; // 2x

    ILeverageToken public leverageToken = ILeverageToken(makeAddr("leverageToken"));

    MockLeverageManager public leverageManager;
    MinMaxCollateralRatioRebalanceAdapterHarness public rebalanceAdapter;

    function setUp() public virtual {
        address rebalanceAdapterImplementation = address(new MinMaxCollateralRatioRebalanceAdapterHarness());
        address rebalanceAdapterProxy = UnsafeUpgrades.deployUUPSProxy(
            rebalanceAdapterImplementation,
            abi.encodeWithSelector(
                MinMaxCollateralRatioRebalanceAdapterHarness.initialize.selector, 1.5 * 1e18, 2.5 * 1e18
            )
        );
        rebalanceAdapter = MinMaxCollateralRatioRebalanceAdapterHarness(rebalanceAdapterProxy);
        leverageManager = new MockLeverageManager();

        rebalanceAdapter.mock_setLeverageManager(ILeverageManager(address(leverageManager)));
    }

    function test_setUp() public virtual {
        bytes32 expectedSlot = keccak256(
            abi.encode(uint256(keccak256("seamless.contracts.storage.MinMaxCollateralRatioRebalanceAdapter")) - 1)
        ) & ~bytes32(uint256(0xff));
        assertEq(rebalanceAdapter.exposed_getMinMaxCollateralRatioRebalanceAdapterStorage(), expectedSlot);
    }

    function _mockCollateralRatio(uint256 collateralRatio) internal {
        leverageManager.setLeverageTokenState(
            leverageToken,
            LeverageTokenState({collateralInDebtAsset: 0, debt: 0, equity: 0, collateralRatio: collateralRatio})
        );
    }
}
