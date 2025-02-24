// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {Test} from "forge-std/Test.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {SwapAdapterHarness} from "test/unit/SwapAdapter/harness/SwapAdapterHarness.t.sol";
import {MockAerodromeRouter} from "test/unit/mock/MockAerodromeRouter.sol";
import {MockAerodromeSlipstreamRouter} from "test/unit/mock/MockAerodromeSlipstreamRouter.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";

contract SwapAdapterBaseTest is Test {
    address public defaultAdmin = makeAddr("defaultAdmin");

    SwapAdapterHarness public swapAdapter;

    MockUniswapRouter02 public mockUniswapRouter02;

    MockAerodromeRouter public mockAerodromeRouter;

    MockAerodromeSlipstreamRouter public mockAerodromeSlipstreamRouter;

    function setUp() public virtual {
        address swapAdapterImplementation = address(new SwapAdapterHarness());
        address swapAdapterProxy = UnsafeUpgrades.deployUUPSProxy(
            swapAdapterImplementation, abi.encodeWithSelector(SwapAdapter.initialize.selector, defaultAdmin)
        );

        swapAdapter = SwapAdapterHarness(swapAdapterProxy);
        mockUniswapRouter02 = new MockUniswapRouter02();
        mockAerodromeRouter = new MockAerodromeRouter();
        mockAerodromeSlipstreamRouter = new MockAerodromeSlipstreamRouter();
    }

    function test_setUp() public view virtual {
        SwapAdapter swapAdapterContract = SwapAdapter(address(swapAdapter));
        assertTrue(swapAdapterContract.hasRole(swapAdapterContract.DEFAULT_ADMIN_ROLE(), defaultAdmin));
    }
}
