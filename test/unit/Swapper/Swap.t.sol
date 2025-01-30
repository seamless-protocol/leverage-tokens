// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {SwapperBaseTest} from "./SwapperBase.t.sol";
import {MockLiFi} from "../mock/MockLiFi.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract SwapTest is SwapperBaseTest {
    function setUp() public override {
        super.setUp();

        vm.prank(manager);
        swapper.setProvider(ISwapper.Provider.LiFi);
    }

    function testFuzz_swap(uint256 fromAmount, uint256 minToAmount) external {
        vm.assume(fromAmount > 0);
        vm.assume(minToAmount > 0);
        bytes memory providerSwapData = hex""; // Doesn't matter as swap call is mocked

        deal(address(fromToken), address(this), fromAmount);

        // Mock the lifi swap call
        lifi.mockNextLifiSwapCall(
            MockLiFi.SwapParams({fromToken: fromToken, toToken: toToken, fromAmount: fromAmount, toAmount: minToAmount})
        );

        fromToken.approve(address(swapper), fromAmount);
        uint256 toAmount = swapper.swap(fromToken, toToken, fromAmount, minToAmount, providerSwapData);
        assertEq(toAmount, minToAmount);
    }

    function testFuzz_swap_RevertIf_SlippageTooHigh(uint256 fromAmount, uint256 minToAmount) external {
        vm.assume(fromAmount > 0);
        vm.assume(minToAmount > 0);
        bytes memory providerSwapData = hex""; // Doesn't matter as swap call is mocked

        deal(address(fromToken), address(this), fromAmount);

        // Mock the lifi swap call
        lifi.mockNextLifiSwapCall(
            MockLiFi.SwapParams({
                fromToken: fromToken,
                toToken: toToken,
                fromAmount: fromAmount,
                toAmount: minToAmount - 1
            })
        );

        fromToken.approve(address(swapper), fromAmount);
        vm.expectRevert(abi.encodeWithSelector(ISwapper.SlippageTooHigh.selector, minToAmount - 1, minToAmount));
        swapper.swap(fromToken, toToken, fromAmount, minToAmount, providerSwapData);
    }

    function test_swap_RevertIf_SwapFailed() external {
        uint256 fromAmount = 100;
        uint256 minToAmount = 100;
        bytes memory providerSwapData = hex""; // Doesn't matter as swap call is mocked

        deal(address(fromToken), address(this), fromAmount);

        fromToken.approve(address(swapper), fromAmount);
        vm.expectRevert(ISwapper.SwapFailed.selector);
        swapper.swap(fromToken, toToken, fromAmount, minToAmount, providerSwapData);
    }
}
