// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {Swapper} from "src/periphery/Swapper.sol";
import {SwapperHarness} from "./harness/SwapperHarness.sol";
import {MockLiFi} from "../mock/MockLiFi.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract SwapperBaseTest is Test {
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");

    MockERC20 public fromToken;
    MockERC20 public toToken;

    SwapperHarness public swapper;

    MockLiFi public lifi;

    function setUp() public virtual {
        fromToken = new MockERC20();
        toToken = new MockERC20();
        lifi = new MockLiFi();

        address swapperImplementation = address(new SwapperHarness());
        swapper = SwapperHarness(
            UnsafeUpgrades.deployUUPSProxy(
                swapperImplementation, abi.encodeWithSelector(Swapper.initialize.selector, defaultAdmin)
            )
        );

        vm.startPrank(defaultAdmin);
        swapper.grantRole(swapper.MANAGER_ROLE(), manager);
        vm.stopPrank();

        vm.prank(manager);
        swapper.setLifi(address(lifi));

        vm.label(address(fromToken), "From Token");
        vm.label(address(toToken), "To Token");
        vm.label(address(lifi), "LiFi");
        vm.label(address(swapper), "Swapper");
    }

    function test_setUp() public view {
        bytes32 expectedSlot = keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.Swapper")) - 1))
            & ~bytes32(uint256(0xff));

        assertTrue(swapper.hasRole(swapper.DEFAULT_ADMIN_ROLE(), defaultAdmin));
        assertEq(swapper.exposed_swapper_layoutSlot(), expectedSlot);

        assertEq(swapper.getLifi(), address(lifi));
    }
}
