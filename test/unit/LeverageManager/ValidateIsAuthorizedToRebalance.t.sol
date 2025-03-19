// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract ValidateIsAllowedToRebalance is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_validateIsAuthorizedToRebalance_RebalanceWhitelistIsZeroAddress() public view {
        // Should not revert because rebalance whitelist is zero address which means everyone can rebalance
        leverageManager.exposed_validateIsAuthorizedToRebalance(strategy);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateIsAuthorizedToRebalance_RebalanceWhitelistIsNotZeroAddress(IRebalanceWhitelist whitelist)
        public
    {
        vm.assume(address(whitelist) != address(0));

        _setRebalanceWhitelist(whitelist);

        vm.mockCall(
            address(whitelist),
            abi.encodeWithSelector(IRebalanceWhitelist.isAllowedToRebalance.selector, address(strategy), address(this)),
            abi.encode(true)
        );

        leverageManager.exposed_validateIsAuthorizedToRebalance(strategy);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateIsAuthorizedToRebalance_RevertIf_NotWhitelisted(IRebalanceWhitelist whitelist) public {
        _setRebalanceWhitelist(whitelist);

        vm.mockCall(
            address(whitelist),
            abi.encodeWithSelector(IRebalanceWhitelist.isAllowedToRebalance.selector, address(strategy), address(this)),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.NotRebalancer.selector, strategy, address(this)));
        leverageManager.exposed_validateIsAuthorizedToRebalance(strategy);
    }

    function _setRebalanceWhitelist(IRebalanceWhitelist whitelist) internal {
        vm.startPrank(manager);
        strategy = leverageManager.createNewStrategy(
            ILeverageManager.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: 1e8,
                maxCollateralRatio: 3e8,
                targetCollateralRatio: 2e8,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: whitelist,
                strategyDepositFee: 0,
                strategyWithdrawFee: 0
            }),
            "",
            ""
        );
        vm.stopPrank();
    }
}
