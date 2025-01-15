// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IMorpho, IMorphoBase} from "src/interfaces/IMorpho.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract MorphoLendingAdapterBorrowTest is MorphoLendingAdapterBaseTest {
    function testFuzz_borrow(uint256 amount) public {
        // Deal Morpho the required debt token amount
        deal(address(debtToken), address(morpho), amount);

        // Expect Morpho.borrow to be called with the correct parameters
        vm.expectCall(
            address(morpho),
            abi.encodeCall(
                IMorphoBase.borrow, (defaultMarketParams, amount, 0, address(lendingAdapter), address(leverageManager))
            )
        );

        vm.prank(address(leverageManager));
        lendingAdapter.borrow(amount);

        assertEq(debtToken.balanceOf(address(leverageManager)), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_borrow_RevertIf_NotLeverageManager(address caller) public {
        vm.assume(caller != address(leverageManager));

        vm.expectRevert(IMorphoLendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        lendingAdapter.borrow(1);
    }
}
