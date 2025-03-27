// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

// Internal imports
import {IDutchAuctionRebalanceAdapter} from "src/interfaces/IDutchAuctionRebalanceAdapter.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";

contract PostLeverageTokenCreation is Test {
    ILeverageManager public leverageManager = ILeverageManager(makeAddr("leverageManager"));
    address public authorizedCreator = makeAddr("authorizedCreator");

    RebalanceAdapter public rebalanceAdapter;

    function setUp() public {
        rebalanceAdapter = new RebalanceAdapter();
        rebalanceAdapter.initialize(address(this), authorizedCreator, leverageManager, 1e8, 3e8, 1 days, 1.1e18, 0.1e18);
    }

    // forge-config: default.fuzz.runs = 1
    function testFuzz_postLeverageTokenCreation(address token) public {
        vm.prank(address(leverageManager));
        rebalanceAdapter.postLeverageTokenCreation(authorizedCreator, token); // Should not revert

        assertEq(address(rebalanceAdapter.getLeverageToken()), token);
    }

    // forge-config: default.fuzz.runs = 1
    function testFuzz_postLeverageTokenCreation_RevertIf_CreatorIsNotAuthorized(address creator, address token)
        public
    {
        vm.assume(creator != authorizedCreator);

        vm.expectRevert(abi.encodeWithSelector(IRebalanceAdapterBase.Unauthorized.selector));
        vm.prank(address(leverageManager));
        rebalanceAdapter.postLeverageTokenCreation(creator, token);
    }

    // forge-config: default.fuzz.runs = 1
    function testFuzz_postLeverageTokenCreation_RevertIf_CallerIsNotLeverageManager(address caller, address token)
        public
    {
        vm.assume(caller != address(leverageManager));

        vm.expectRevert(abi.encodeWithSelector(IRebalanceAdapterBase.Unauthorized.selector));
        vm.prank(caller);
        rebalanceAdapter.postLeverageTokenCreation(authorizedCreator, token);
    }

    // forge-config: default.fuzz.runs = 1
    function test_postLeverageTokenCreation_RevertIf_LeverageTokenAlreadySet(address token) public {
        vm.prank(address(leverageManager));
        rebalanceAdapter.postLeverageTokenCreation(authorizedCreator, token);

        vm.expectRevert(abi.encodeWithSelector(IDutchAuctionRebalanceAdapter.LeverageTokenAlreadySet.selector));
        vm.prank(address(leverageManager));
        rebalanceAdapter.postLeverageTokenCreation(authorizedCreator, token);
    }
}
