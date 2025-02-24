// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {Test} from "forge-std/Test.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {SwapAdapterHarness} from "test/unit/SwapAdapter/harness/SwapAdapterHarness.t.sol";

contract SwapAdapterBaseTest is Test {
    address public defaultAdmin = makeAddr("defaultAdmin");

    SwapAdapterHarness public swapAdapter;

    function setUp() public virtual {
        address swapAdapterImplementation = address(new SwapAdapterHarness());
        address swapAdapterProxy = UnsafeUpgrades.deployUUPSProxy(
            swapAdapterImplementation, abi.encodeWithSelector(SwapAdapter.initialize.selector, defaultAdmin)
        );

        swapAdapter = SwapAdapterHarness(swapAdapterProxy);
    }

    function test_setUp() public view virtual {
        SwapAdapter swapAdapterContract = SwapAdapter(address(swapAdapter));
        assertTrue(swapAdapterContract.hasRole(swapAdapterContract.DEFAULT_ADMIN_ROLE(), defaultAdmin));
    }
}
