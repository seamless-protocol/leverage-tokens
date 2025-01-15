// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ConvertToShares is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_convertToShares_RoundedDown() public {
        uint128 equity = 1;
        uint128 totalEquity = 100;
        uint128 sharesTotalSupply = 99;

        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(strategy, equity);
        assertEq(shares, 0);
    }

    function testFuzz_convertToShares(uint128 equity, uint128 totalEquity, uint128 sharesTotalSupply) public {
        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(strategy, equity);
        uint256 expectedShares = equity * (uint256(sharesTotalSupply) + 1) / (uint256(totalEquity) + 1);

        assertEq(shares, expectedShares);
    }
}
