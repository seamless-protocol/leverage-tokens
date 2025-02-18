// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract ValidateIsAllowedToRebalance is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_validateIsAuthorizedToRebalance_RebalanceWhitelistIsZeroAddress() public view {
        // Should not revert because rebalance whitelist is zero address which means everyone can rebalance
        leverageManager.exposed_validateIsAuthorizedToRebalance(strategy);
    }

    function test_validateIsAuthorizedToRebalance_RebalanceWhitelistIsNotZeroAddress(IRebalanceWhitelist whitelist)
        public
    {
        vm.assume(address(whitelist) != address(0));

        _setStrategyRebalanceWhitelist(manager, whitelist);

        vm.mockCall(
            address(whitelist),
            abi.encodeWithSelector(IRebalanceWhitelist.isAllowedToRebalance.selector, address(strategy), address(this)),
            abi.encode(true)
        );

        leverageManager.exposed_validateIsAuthorizedToRebalance(strategy);
    }

    function test_validateIsAuthorizedToRebalance_NotWhitelisted(IRebalanceWhitelist whitelist) public {
        _setStrategyRebalanceWhitelist(manager, whitelist);

        vm.mockCall(
            address(whitelist),
            abi.encodeWithSelector(IRebalanceWhitelist.isAllowedToRebalance.selector, address(strategy), address(this)),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.NotRebalancer.selector, strategy, address(this)));
        leverageManager.exposed_validateIsAuthorizedToRebalance(strategy);
    }
}
