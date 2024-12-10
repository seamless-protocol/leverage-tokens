// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {BaseTest} from "./Base.t.sol";

contract CalculateDebtAndSharesTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyCap(address strategy, uint256 cap) public {}
}
