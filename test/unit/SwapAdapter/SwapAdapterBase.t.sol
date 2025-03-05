// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {Test} from "forge-std/Test.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {SwapAdapterHarness} from "test/unit/SwapAdapter/harness/SwapAdapterHarness.t.sol";
import {MockAerodromeRouter} from "test/unit/mock/MockAerodromeRouter.sol";
import {MockAerodromeSlipstreamRouter} from "test/unit/mock/MockAerodromeSlipstreamRouter.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockUniswapSwapRouter02} from "test/unit/mock/MockUniswapSwapRouter02.sol";
import {MockUniswapV2Router02} from "test/unit/mock/MockUniswapV2Router02.sol";

contract SwapAdapterBaseTest is Test {
    address public defaultAdmin = makeAddr("defaultAdmin");

    MockERC20 public fromToken = new MockERC20();
    MockERC20 public toToken = new MockERC20();

    SwapAdapterHarness public swapAdapter;

    MockUniswapSwapRouter02 public mockUniswapSwapRouter02;

    MockUniswapV2Router02 public mockUniswapV2Router02;

    MockAerodromeRouter public mockAerodromeRouter;

    MockAerodromeSlipstreamRouter public mockAerodromeSlipstreamRouter;

    function setUp() public virtual {
        address swapAdapterImplementation = address(new SwapAdapterHarness());
        address swapAdapterProxy = UnsafeUpgrades.deployUUPSProxy(
            swapAdapterImplementation, abi.encodeWithSelector(SwapAdapter.initialize.selector, defaultAdmin)
        );

        swapAdapter = SwapAdapterHarness(swapAdapterProxy);
        mockUniswapSwapRouter02 = new MockUniswapSwapRouter02();
        mockUniswapV2Router02 = new MockUniswapV2Router02();
        mockAerodromeRouter = new MockAerodromeRouter();
        mockAerodromeSlipstreamRouter = new MockAerodromeSlipstreamRouter();
    }

    function test_setUp() public view virtual {
        SwapAdapter swapAdapterContract = SwapAdapter(address(swapAdapter));
        assertTrue(swapAdapterContract.hasRole(swapAdapterContract.DEFAULT_ADMIN_ROLE(), defaultAdmin));
    }
}
