// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IMorpho, IMorphoBase} from "src/interfaces/IMorpho.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract MorphoLendingAdapterBorrowTest is MorphoLendingAdapterBaseTest {
    function testFuzz_borrow(uint256 amount) public {
        // Mock the borrow call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(
                IMorphoBase.borrow.selector,
                defaultMarketParams,
                amount,
                0,
                address(lendingAdapter),
                address(leverageManager)
            ),
            abi.encode(0, 0) // Mocked return values that are not used
        );

        // Expect Morpho.borrow to be called with the correct parameters
        vm.expectCall(
            address(morpho),
            abi.encodeCall(
                IMorphoBase.borrow, (defaultMarketParams, amount, 0, address(lendingAdapter), address(leverageManager))
            )
        );

        vm.prank(address(leverageManager));
        lendingAdapter.borrow(amount);
    }

    function testFuzz_borrow_RevertIf_NotLeverageManager(address caller) public {
        vm.assume(caller != address(leverageManager));

        vm.expectRevert(IMorphoLendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        lendingAdapter.borrow(1);
    }
}
