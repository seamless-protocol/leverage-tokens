// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IMorpho, IMorphoBase} from "src/vendor/morpho/IMorpho.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract MorphoLendingAdapterAddCollateralTest is MorphoLendingAdapterBaseTest {
    address public alice = makeAddr("alice");

    function testFuzz_addCollateral(uint256 amount) public {
        // Deal alice the required collateral
        deal(address(collateralToken), alice, amount);

        // Mock the idToMarketParams call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(IMorpho.idToMarketParams.selector, defaultMarketId),
            abi.encode(defaultMarketParams)
        );
        // Mock the supplyCollateral call to morpho
        vm.mockCall(
            address(morpho),
            abi.encodeWithSelector(
                IMorphoBase.supplyCollateral.selector, defaultMarketParams, amount, address(lendingAdapter), hex""
            ),
            abi.encode()
        );

        // Alice approves the lending adapter to spend her assets
        vm.startPrank(alice);
        collateralToken.approve(address(lendingAdapter), amount);

        // Expect the Alice's assets to be transferred to the lending adapter
        vm.expectCall(
            address(collateralToken),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(lendingAdapter), amount)
        );
        // Expect LendingAdapter.addCollateral to approve the morpho market to spend the assets for the amount
        vm.expectCall(
            address(collateralToken), abi.encodeWithSelector(IERC20.approve.selector, address(morpho), amount)
        );
        // Expect Morpho.supplyCollateral to be called with the correct parameters
        vm.expectCall(
            address(morpho),
            abi.encodeCall(IMorphoBase.supplyCollateral, (defaultMarketParams, amount, address(lendingAdapter), hex""))
        );
        lendingAdapter.addCollateral(makeAddr("random"), amount);
        vm.stopPrank();
    }
}
