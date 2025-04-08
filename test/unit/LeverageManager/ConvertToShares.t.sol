// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {LeverageManagerTest} from "test/unit/LeverageManager/LeverageManager.t.sol";

contract ConvertToSharesTest is LeverageManagerTest {
    function setUp() public override {
        super.setUp();

        _createDummyLeverageToken();
    }

    function test_convertToShares_DepositRoundsDown() public {
        uint128 equity = 1;
        uint128 sharesTotalSupply = 99;
        uint128 totalEquity = 100;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Deposit);
        assertEq(shares, 0);
    }

    function testFuzz_convertToShares_DepositRoundsDown(uint128 equity, uint128 totalEquity, uint128 sharesTotalSupply)
        public
    {
        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Deposit);
        uint256 expectedShares = equity * (uint256(sharesTotalSupply) + 1) / (uint256(totalEquity) + 1);

        assertEq(shares, expectedShares);
    }

    function test_convertToShares_WithdrawRoundsUp() public {
        uint128 equity = 1;
        uint128 sharesTotalSupply = 99;
        uint128 totalEquity = 100;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Withdraw);
        assertEq(shares, 1);
    }

    function testFuzz_convertToShares_WithdrawRoundsUp(uint128 equity, uint128 totalEquity, uint128 sharesTotalSupply)
        public
    {
        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Withdraw);
        uint256 expectedShares = Math.mulDiv(equity, uint256(sharesTotalSupply) + 1, uint256(totalEquity) + 1, Math.Rounding.Ceil);

        assertEq(shares, expectedShares);
    }
}
