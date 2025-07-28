// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Internal imports
import {LeverageManagerTest} from "test/unit/LeverageManager/LeverageManager.t.sol";

contract ConvertEquityToSharesTest is LeverageManagerTest {
    function setUp() public override {
        super.setUp();

        _createDummyLeverageToken();
    }

    function test_convertEquityToShares() public {
        uint128 equity = 1;
        uint128 sharesTotalSupply = 99;
        uint128 totalEquity = 100;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        assertEq(shares, 0);

        shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Ceil);
        assertEq(shares, 1);
    }

    function testFuzz_convertEquityToShares(uint128 equity, uint128 totalEquity, uint128 sharesTotalSupply) public {
        totalEquity = uint128(bound(totalEquity, 1, type(uint128).max));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        uint256 expectedShares = uint256(equity) * sharesTotalSupply / totalEquity;
        assertEq(shares, expectedShares);

        shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Ceil);
        expectedShares = Math.mulDiv(equity, sharesTotalSupply, totalEquity, Math.Rounding.Ceil);
        assertEq(shares, expectedShares);
    }

    function testFuzz_convertEquityToShares_EmptyLeverageToken_CollateralAsset18Decimals(
        uint128 equity,
        uint128 nonZeroValue
    ) public {
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

        uint256 shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        assertEq(shares, equity);

        totalEquity = nonZeroValue;
        sharesTotalSupply = 0;

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Ceil);
        assertEq(shares, equity);
    }

    function testFuzz_convertEquityToShares_EmptyLeverageToken_CollateralAssetLessThan18Decimals(uint128 equity)
        public
    {
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

        uint256 shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        uint256 expectedShares = uint256(equity) * 1e12;
        assertEq(shares, expectedShares);
    }

    function testFuzz_convertEquityToShares_EmptyLeverageToken_CollateralAssetMoreThan18Decimals(uint256 equity)
        public
    {
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

        uint256 shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        assertEq(shares, equity / 1e9);
    }

    function test_convertEquityToShares_WithManagementFee() public {
        uint128 equity = 10;
        uint128 sharesTotalSupply = 99;
        uint128 totalEquity = 100;

        uint256 managementFee = 0.1e4; // 10%
        _setManagementFee(feeManagerRole, leverageToken, managementFee);
        feeManager.chargeManagementFee(leverageToken);

        _mockState_ConvertToShares(
            ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: sharesTotalSupply})
        );

        uint256 shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        assertEq(shares, 9);

        shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Ceil);
        assertEq(shares, 10);

        // One year passes
        skip(SECONDS_ONE_YEAR);

        // Shares should be slightly more than 10 because of the management fee increasing the virtual total supply
        shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Floor);
        assertEq(shares, 10);

        shares = leverageManager.convertEquityToShares(leverageToken, equity, Math.Rounding.Ceil);
        assertEq(shares, 11);
    }
}
