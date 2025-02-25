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
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";

contract SwapAdapterBaseTest is Test {
    address public defaultAdmin = makeAddr("defaultAdmin");

    MockERC20 public fromToken = new MockERC20();
    MockERC20 public toToken = new MockERC20();

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

    /// @notice Encode the path as required by the Aerodrome Slipstream router
    function _encodeAerodromeSlipstreamPath(address[] memory path, int24[] memory tickSpacing, bool reverseOrder)
        internal
        pure
        returns (bytes memory encodedPath)
    {
        if (reverseOrder) {
            encodedPath = abi.encodePacked(path[path.length - 1]);
            for (uint256 i = tickSpacing.length; i > 0; i--) {
                uint256 indexToAppend = i - 1;
                encodedPath = abi.encodePacked(encodedPath, tickSpacing[indexToAppend], path[indexToAppend]);
            }
        } else {
            encodedPath = abi.encodePacked(path[0]);
            for (uint256 i = 0; i < tickSpacing.length; i++) {
                encodedPath = abi.encodePacked(encodedPath, tickSpacing[i], path[i + 1]);
            }
        }
    }

    /// @notice Encode the path as required by the Uniswap V3 router
    function _encodeUniswapV3Path(address[] memory path, uint24[] memory fees, bool reverseOrder)
        internal
        pure
        returns (bytes memory encodedPath)
    {
        if (reverseOrder) {
            encodedPath = abi.encodePacked(path[path.length - 1]);
            for (uint256 i = fees.length; i > 0; i--) {
                uint256 indexToAppend = i - 1;
                encodedPath = abi.encodePacked(encodedPath, fees[indexToAppend], path[indexToAppend]);
            }
        } else {
            encodedPath = abi.encodePacked(path[0]);
            for (uint256 i = 0; i < fees.length; i++) {
                encodedPath = abi.encodePacked(encodedPath, fees[i], path[i + 1]);
            }
        }
    }
}
