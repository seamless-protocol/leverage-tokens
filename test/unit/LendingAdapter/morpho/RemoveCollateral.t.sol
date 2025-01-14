// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IMorpho, IMorphoBase} from "src/interfaces/IMorpho.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract MorphoLendingAdapterRemoveCollateralTest is MorphoLendingAdapterBaseTest {
    function testFuzz_removeCollateral(uint256 amount) public {
        // Mock the withdrawCollateral call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(
                IMorphoBase.withdrawCollateral.selector,
                defaultMarketParams,
                amount,
                address(lendingAdapter),
                address(leverageManager)
            ),
            abi.encode()
        );

        // Expect Morpho.withdrawCollateral to be called with the correct parameters
        vm.expectCall(
            address(morpho),
            abi.encodeCall(
                IMorphoBase.withdrawCollateral,
                (defaultMarketParams, amount, address(lendingAdapter), address(leverageManager))
            )
        );
        vm.prank(address(leverageManager));
        lendingAdapter.removeCollateral(amount);
    }

    function testFuzz_removeCollateral_RevertIf_NotLeverageManager(address caller) public {
        vm.assume(caller != address(leverageManager));

        vm.expectRevert(IMorphoLendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        lendingAdapter.removeCollateral(1);
    }
}
