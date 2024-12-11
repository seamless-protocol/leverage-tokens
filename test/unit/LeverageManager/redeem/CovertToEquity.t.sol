// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ConvertToEquity is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_convertToEquity(address strategy, uint128 shares, uint128 totalEquity, uint128 sharesTotalSupply)
        public
    {
        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({strategy: strategy, totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 equity = leverageManager.convertToEquity(strategy, shares);
        uint256 expectedEquity = shares * (uint256(totalEquity) + 1) / (uint256(sharesTotalSupply) + 1);

        assertEq(equity, expectedEquity);
    }
}
