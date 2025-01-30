// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {Swapper} from "src/periphery/Swapper.sol";
import {MockLiFi} from "../mock/MockLiFi.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract SwapperBaseTest is Test {
    MockERC20 public fromToken;
    MockERC20 public toToken;

    Swapper public swapper;

    MockLiFi public lifi;

    function setUp() public virtual {
        fromToken = new MockERC20();
        toToken = new MockERC20();
        lifi = new MockLiFi();
        swapper = new Swapper(ISwapper.Provider.LiFi, address(lifi));

        vm.label(address(fromToken), "From Token");
        vm.label(address(toToken), "To Token");
        vm.label(address(lifi), "LiFi");
        vm.label(address(swapper), "Swapper");
    }

    function test_setUp() public view {
        assertEq(uint256(swapper.provider()), uint256(ISwapper.Provider.LiFi));
        assertEq(swapper.lifi(), address(lifi));
    }

    function test_setProvider() public {
        swapper.setProvider(ISwapper.Provider.LiFi);
        assertEq(uint256(swapper.provider()), uint256(ISwapper.Provider.LiFi));
    }
}
