// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IMorpho, IMorphoBase} from "src/interfaces/IMorpho.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract MorphoLendingAdapterRepayTest is MorphoLendingAdapterBaseTest {
    address public alice = makeAddr("alice");

    function testFuzz_repay(uint256 amount) public {
        // Deal alice the required debt
        deal(address(debtToken), alice, amount);

        // Mock the repay call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(
                IMorphoBase.repay.selector, defaultMarketParams, amount, 0, address(lendingAdapter), hex""
            ),
            abi.encode(0, 0) // Mocked return values that are not used
        );

        // Alice approves the lending adapter to spend her assets
        vm.startPrank(alice);
        debtToken.approve(address(lendingAdapter), amount);

        // Expect the Alice's assets to be transferred to the lending adapter
        vm.expectCall(
            address(debtToken),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(lendingAdapter), amount)
        );
        // Expect LendingAdapter.repay to approve the morpho market to spend the assets for the amount
        vm.expectCall(address(debtToken), abi.encodeWithSelector(IERC20.approve.selector, address(morpho), amount));
        // Expect Morpho.repay to be called with the correct parameters
        vm.expectCall(
            address(morpho),
            abi.encodeCall(IMorphoBase.repay, (defaultMarketParams, amount, 0, address(lendingAdapter), hex""))
        );
        lendingAdapter.repay(amount);
        vm.stopPrank();
    }
}
