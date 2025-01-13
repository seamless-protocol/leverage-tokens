// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IMorpho, IMorphoBase} from "src/vendor/morpho/IMorpho.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract MorphoLendingAdapterRemoveCollateralTest is MorphoLendingAdapterBaseTest {

    address public alice = makeAddr("alice");

    function testFuzz_removeCollateral(uint256 amount) public {
        // Mock the idToMarketParams call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(IMorpho.idToMarketParams.selector, defaultMarketId),
            abi.encode(defaultMarketParams)
        );
        // Mock the withdrawCollateral call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(IMorphoBase.withdrawCollateral.selector, defaultMarketParams, amount, address(lendingAdapter), alice),
            abi.encode()
        );

        // Expect Morpho.withdrawCollateral to be called with the correct parameters
        vm.expectCall(
            address(morpho),
            abi.encodeCall(IMorphoBase.withdrawCollateral, (defaultMarketParams, amount, address(lendingAdapter), alice))
        );
        vm.prank(alice);
        lendingAdapter.removeCollateral(makeAddr("random"), amount);
    }
}

