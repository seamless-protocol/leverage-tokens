// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract RedeemTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Redeem() external {}
}
