// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ConvertToEquity is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_convertToEquity_RoundedDown() public {
        uint128 shares = 1;
        uint128 totalEquity = 99;
        uint128 sharesTotalSupply = 100;

        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 equity = leverageManager.exposed_convertToEquity(strategy, shares);
        assertEq(equity, 0);
    }

    function testFuzz_convertToShares(uint128 shares, uint128 totalEquity, uint128 sharesTotalSupply) public {
        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 equity = leverageManager.exposed_convertToEquity(strategy, shares);
        uint256 expectedEquity = shares * (uint256(totalEquity) + 1) / (uint256(sharesTotalSupply) + 1);

        assertEq(equity, expectedEquity);
    }
}
