// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract MintSharesTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_mintShares_OneMint(address user, uint256 amount) public {
        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Mint(strategy, user, amount);

        _mintShares(user, amount);

        assertEq(leverageManager.getTotalStrategyShares(strategy), amount);
        assertEq(leverageManager.getUserStrategyShares(strategy, user), amount);
    }

    function testFuzz_mintShares_TwoMints(address user, uint128 amount1, uint128 amount2) public {
        _mintShares(user, amount1);
        _mintShares(user, amount2);

        assertEq(leverageManager.getTotalStrategyShares(strategy), uint256(amount1) + amount2);
        assertEq(leverageManager.getUserStrategyShares(strategy, user), uint256(amount1) + amount2);
    }
}
