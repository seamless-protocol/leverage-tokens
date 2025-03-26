// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract PreLeverageTokenCreation is MorphoLendingAdapterBaseTest {
    // forge-config: default.fuzz.runs = 1
    function testFuzz_preLeverageTokenCreation(address creator) public {
        lendingAdapter = new MorphoLendingAdapter(leverageManager, IMorpho(address(morpho)));
        MorphoLendingAdapter(address(lendingAdapter)).initialize(defaultMarketId, creator);

        vm.prank(address(leverageManager));
        lendingAdapter.preLeverageTokenCreation(creator); // Should not revert
    }

    // forge-config: default.fuzz.runs = 1
    function testFuzz_preLeverageTokenCreation_RevertIf_CreatorIsNotAuthorized(address creator) public {
        vm.assume(creator != authorizedCreator);

        vm.expectRevert(abi.encodeWithSelector(ILendingAdapter.Unauthorized.selector));
        vm.prank(address(leverageManager));
        lendingAdapter.preLeverageTokenCreation(creator);
    }

    // forge-config: default.fuzz.runs = 1
    function testFuzz_preLeverageTokenCreation_RevertIf_CallerIsNotLeverageManager(address caller) public {
        vm.assume(caller != address(leverageManager));

        vm.expectRevert(abi.encodeWithSelector(ILendingAdapter.Unauthorized.selector));
        vm.prank(caller);
        lendingAdapter.preLeverageTokenCreation(authorizedCreator);
    }

    function test_preLeverageTokenCreation_RevertIf_LendingAdapterIsAlreadyUsed() public {
        vm.prank(address(leverageManager));
        lendingAdapter.preLeverageTokenCreation(authorizedCreator);

        vm.expectRevert(abi.encodeWithSelector(IMorphoLendingAdapter.LendingAdapterAlreadyInUse.selector));
        vm.prank(address(leverageManager));
        lendingAdapter.preLeverageTokenCreation(authorizedCreator);
    }
}
