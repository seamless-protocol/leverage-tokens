// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ConvertToShares is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_convertToShares(address strategy, uint128 equity, uint128 totalEquity, uint128 sharesTotalSupply)
        public
    {
        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({strategy: strategy, totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(strategy, equity);
        uint256 expectedShares = equity * (uint256(sharesTotalSupply) + 1) / (uint256(totalEquity) + 1);

        assertEq(shares, expectedShares);
    }
}
