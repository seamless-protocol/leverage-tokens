// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VeloraAdapterTest} from "./VeloraAdapter.t.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";

contract BuyTest is VeloraAdapterTest {
    function test_buy_RevertIf_InvalidAugustus(address _augustus) public {
        augustusRegistry.setValid(_augustus, false);

        vm.expectRevert("INVALID_AUGUSTUS");
        veloraAdapter.buy(
            _augustus,
            new bytes(32),
            address(collateralToken),
            address(debtToken),
            0,
            IVeloraAdapter.Offsets(0, 0, 0),
            address(0)
        );
    }

    function test_buy_RevertIf_ZeroMinDestAmount() public {
        vm.expectRevert("ZERO_MIN_DEST_AMOUNT");
        veloraAdapter.buy(
            address(augustus),
            new bytes(32),
            address(collateralToken),
            address(debtToken),
            0,
            IVeloraAdapter.Offsets(0, 0, 0),
            address(0xBEEF)
        );
    }

    function test_buy_RevertIf_ZeroReceiver() public {
        vm.expectRevert("ZERO_ADDRESS");
        veloraAdapter.buy(
            address(augustus),
            new bytes(32),
            address(collateralToken),
            address(debtToken),
            1,
            IVeloraAdapter.Offsets(0, 0, 0),
            address(0)
        );
    }

    function test_buy_UpdateAmountsBuyWithQuoteUpdate(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 newLimit,
        uint256 offset
    ) public {
        deal(address(collateralToken), address(veloraAdapter), newLimit); // The new limit is the balance of the adapter
        _updateAmountsBuy(_augustus, initialExact, initialLimit, initialQuoted, adjustedExact, newLimit, offset, true);
    }

    function test_buy_UpdateAmountsBuyNoQuoteUpdate(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 newLimit,
        uint256 offset
    ) public {
        deal(address(collateralToken), address(veloraAdapter), newLimit); // The new limit is the balance of the adapter
        _updateAmountsBuy(_augustus, initialExact, initialLimit, initialQuoted, adjustedExact, newLimit, offset, false);
    }

    function test_buy_ExactAmountCheck(uint256 amount, uint256 subAmount) public {
        amount = bound(amount, 1, type(uint64).max);
        subAmount = bound(subAmount, 0, amount - 1);

        deal(address(collateralToken), address(veloraAdapter), amount);

        augustus.setToGive(subAmount);
        vm.expectRevert("BUY_AMOUNT_TOO_LOW");
        _buy(address(collateralToken), address(debtToken), amount, amount, 0, address(0xBEEF));
    }

    function test_buy_NoAdjustment(uint256 amount, uint256 extra, address receiver) public {
        _receiver(receiver);

        amount = bound(amount, 1, type(uint128).max);
        extra = bound(extra, 0, type(uint128).max);

        deal(address(collateralToken), address(veloraAdapter), amount + extra);
        _buy(address(collateralToken), address(debtToken), amount, amount, 0, receiver);

        assertEq(collateralToken.balanceOf(address(this)), extra, "sender received excess input token");
        assertEq(debtToken.balanceOf(receiver), amount, "receiver received output token");
        assertEq(collateralToken.balanceOf(address(veloraAdapter)), 0, "velora adapter has no input token");
        assertEq(debtToken.balanceOf(address(veloraAdapter)), 0, "velora adapter has no output token");
        assertEq(collateralToken.allowance(address(veloraAdapter), address(augustus)), 0, "augustus has no allowance");
    }

    function test_buy_WithAdjustment(uint256 destAmount, uint256 percent, address receiver) public {
        _receiver(receiver);

        percent = bound(percent, 1, 1000);
        destAmount = bound(destAmount, 1, type(uint64).max);
        uint256 actualDestAmount = Math.mulDiv(destAmount, percent, 100, Math.Rounding.Ceil);

        deal(address(collateralToken), address(veloraAdapter), actualDestAmount);

        _buy(address(collateralToken), address(debtToken), destAmount, destAmount, actualDestAmount, receiver);

        assertEq(collateralToken.balanceOf(address(this)), 0, "sender received excess input token");
        assertEq(debtToken.balanceOf(receiver), actualDestAmount, "receiver received output token");
        assertEq(collateralToken.balanceOf(address(veloraAdapter)), 0, "velora adapter has no input token");
        assertEq(debtToken.balanceOf(address(veloraAdapter)), 0, "velora adapter has no output token");
        assertEq(collateralToken.allowance(address(veloraAdapter), address(augustus)), 0, "augustus has no allowance");
    }

    function _buy(
        address srcToken,
        address destToken,
        uint256 maxSrcAmount,
        uint256 destAmount,
        uint256 newDestAmount,
        address receiver
    ) internal {
        uint256 fromAmountOffset = 4 + 32 + 32;
        uint256 toAmountOffset = fromAmountOffset + 32;

        veloraAdapter.buy(
            address(augustus),
            abi.encodeCall(augustus.mockBuy, (srcToken, destToken, maxSrcAmount, destAmount)),
            srcToken,
            destToken,
            newDestAmount,
            IVeloraAdapter.Offsets({exactAmount: toAmountOffset, limitAmount: fromAmountOffset, quotedAmount: 0}),
            receiver
        );
    }

    // Checks that the adapter correctly adjusts amounts sent to augustus.
    // Expects a revert since the augustus address will not swap the tokens.
    function _updateAmountsBuy(
        address _augustus,
        uint256 initialExact,
        uint256 initialLimit,
        uint256 initialQuoted,
        uint256 adjustedExact,
        uint256 newLimit,
        uint256 offset,
        bool adjustQuoted
    ) internal {
        _makeEmptyAccountCallable(_augustus);
        augustusRegistry.setValid(_augustus, true);

        offset = _boundOffset(offset);

        initialExact = bound(initialExact, 1, type(uint64).max);
        initialLimit = bound(initialLimit, 0, type(uint64).max);
        initialQuoted = bound(initialQuoted, 0, type(uint64).max);
        adjustedExact = bound(adjustedExact, 1, type(uint64).max);

        uint256 adjustedLimit = newLimit;

        uint256 adjustedQuoted;
        uint256 quotedOffset;
        if (adjustQuoted) {
            adjustedQuoted = Math.mulDiv(initialQuoted, adjustedExact, initialExact, Math.Rounding.Floor);
            quotedOffset = offset + 64;
        } else {
            adjustedQuoted = initialQuoted;
            quotedOffset = 0;
        }

        vm.expectRevert("BUY_AMOUNT_TOO_LOW");
        vm.expectCall(address(_augustus), _swapCalldata(offset, adjustedExact, adjustedLimit, adjustedQuoted));
        veloraAdapter.buy(
            _augustus,
            _swapCalldata(offset, initialExact, initialLimit, initialQuoted),
            address(collateralToken),
            address(debtToken),
            adjustedExact,
            IVeloraAdapter.Offsets(offset, offset + 32, quotedOffset),
            address(1)
        );
    }
}
