// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Internal imports
import {LeverageManagerTest} from "test/unit/LeverageManager/LeverageManager.t.sol";

contract ConvertSharesToEquityTest is LeverageManagerTest {
    function setUp() public override {
        super.setUp();

        _createDummyLeverageToken();
    }

    function test_convertSharesToEquity() public {
        uint128 shares = 1;
        uint128 totalEquity = 99;
        uint128 totalSupply = 100;

        _mockState_ConvertToShares(ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: totalSupply}));

        uint256 equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, 0);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, 1);
    }

    function testFuzz_convertSharesToEquity(uint128 shares, uint128 totalEquity, uint128 totalSupply) public {
        totalEquity = uint128(bound(totalEquity, 1, type(uint128).max));
        totalSupply = uint128(bound(totalSupply, 1, type(uint128).max));

        _mockState_ConvertToShares(ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: totalSupply}));

        uint256 equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        uint256 expectedEquity = Math.mulDiv(shares, totalEquity, totalSupply, Math.Rounding.Floor);
        assertEq(equity, expectedEquity);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        expectedEquity = Math.mulDiv(shares, totalEquity, totalSupply, Math.Rounding.Ceil);
        assertEq(equity, expectedEquity);
    }

    function testFuzz_convertSharesToEquity_EmptyLeverageToken_CollateralAsset18Decimals(
        uint128 shares,
        uint128 nonZeroValue
    ) public {
        uint256 totalEquity = 0;
        uint256 totalSupply = nonZeroValue;

        _mockState_ConvertToShares(ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: totalSupply}));
        vm.mockCall(
            address(lendingAdapter.getCollateralAsset()),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );

        uint256 equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, shares);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, shares);

        totalEquity = nonZeroValue;
        _mockLeverageTokenTotalEquityInCollateralAsset(totalEquity);
        _burnShares(address(1), totalSupply); // Burn all shares

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, shares);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, shares);
    }

    function testFuzz_convertSharesToEquity_EmptyLeverageToken_CollateralAssetLessThan18Decimals(
        uint128 shares,
        uint256 nonZeroValue
    ) public {
        uint256 totalEquity = 0;
        uint256 totalSupply = nonZeroValue;

        _mockState_ConvertToShares(ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: totalSupply}));

        vm.mockCall(
            address(lendingAdapter.getCollateralAsset()),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(6)
        );

        uint256 scalingFactor = 10 ** (18 - 6);
        uint256 expectedEquity = uint256(shares) / scalingFactor;

        uint256 equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, expectedEquity);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, expectedEquity);

        totalEquity = nonZeroValue;
        _mockLeverageTokenTotalEquityInCollateralAsset(totalEquity);
        _burnShares(address(1), totalSupply); // Burn all shares

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, expectedEquity);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, expectedEquity);
    }

    function testFuzz_convertSharesToEquity_EmptyLeverageToken_CollateralAssetMoreThan18Decimals(
        uint128 shares,
        uint256 nonZeroValue
    ) public {
        uint256 totalEquity = 0;
        uint256 totalSupply = nonZeroValue;

        _mockState_ConvertToShares(ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: totalSupply}));

        vm.mockCall(
            address(lendingAdapter.getCollateralAsset()),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(27)
        );

        uint256 scalingFactor = 10 ** (27 - 18);
        uint256 expectedEquity = uint256(shares) * scalingFactor;

        uint256 equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, expectedEquity);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, expectedEquity);

        totalEquity = nonZeroValue;
        _mockLeverageTokenTotalEquityInCollateralAsset(totalEquity);
        _burnShares(address(1), totalSupply); // Burn all shares

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, expectedEquity);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, expectedEquity);
    }

    function test_convertSharesToEquity_WithManagementFee() public {
        uint128 shares = 10;
        uint128 totalEquity = 99;
        uint128 totalSupply = 100;

        uint256 managementFee = 0.5e4; // 50%
        _setManagementFee(feeManagerRole, leverageToken, managementFee);
        feeManager.chargeManagementFee(leverageToken);

        _mockState_ConvertToShares(ConvertToSharesState({totalEquity: totalEquity, sharesTotalSupply: totalSupply}));

        uint256 equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, 9);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, 10);

        // One year passes
        skip(SECONDS_ONE_YEAR);

        // Equity should be less due to the management fee increasing the virtual total supply
        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Floor);
        assertEq(equity, 6);

        equity = leverageManager.convertSharesToEquity(leverageToken, shares, Math.Rounding.Ceil);
        assertEq(equity, 7);
    }
}
