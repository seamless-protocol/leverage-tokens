// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
        totalEquity = uint128(bound(totalEquity, 1, type(uint128).max));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Deposit);
        uint256 expectedShares = uint256(equity) * sharesTotalSupply / totalEquity;
        assertEq(shares, expectedShares);
    }

    function testFuzz_convertToShares_EmptyLeverageToken_18Decimals(uint128 equity, uint128 nonZeroValue) public {
        uint256 totalEquity = 0;
        uint256 sharesTotalSupply = nonZeroValue;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );
        vm.mockCall(
            address(lendingAdapter.getCollateralAsset()),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Deposit);
        assertEq(shares, equity);

        totalEquity = nonZeroValue;
        sharesTotalSupply = 0;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Withdraw);
        assertEq(shares, equity);
    }

    function testFuzz_convertToShares_EmptyLeverageToken_LessThan18Decimals(uint128 equity) public {
        uint256 totalEquity = 0;
        uint256 sharesTotalSupply = 0;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        vm.mockCall(
            address(lendingAdapter.getCollateralAsset()),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(6)
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Deposit);
        uint256 expectedShares = uint256(equity) * 1e12;
        assertEq(shares, expectedShares);
    }

    function testFuzz_convertToShares_EmptyLeverageToken_MoreThan18Decimals(uint256 equity) public {
        uint256 totalEquity = 0;
        uint256 sharesTotalSupply = 100;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        vm.mockCall(
            address(lendingAdapter.getCollateralAsset()),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(27)
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Deposit);
        assertEq(shares, equity / 1e9);
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
        totalEquity = uint128(bound(totalEquity, 1, type(uint128).max));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.exposed_convertToShares(leverageToken, equity, ExternalAction.Withdraw);
        uint256 expectedShares = Math.mulDiv(equity, sharesTotalSupply, totalEquity, Math.Rounding.Ceil);

        assertEq(shares, expectedShares);
    }
}
