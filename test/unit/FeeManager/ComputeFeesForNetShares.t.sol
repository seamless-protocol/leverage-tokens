// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ComputeTokenFeeForNetSharesTest is FeeManagerTest {
    function test_computeTokenFeeForNetShares() public {
        uint256 shares = 1 ether;
        uint256 mintTokenFee = 200;
        uint256 mintTreasuryFee = 400;
        uint256 redeemTokenFee = 600;
        uint256 redeemTreasuryFee = 800;

        _setLeverageTokenActionFees(mintTokenFee, redeemTokenFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, mintTreasuryFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Redeem, redeemTreasuryFee);

        (uint256 grossShares, uint256 tokenFee, uint256 treasuryFee) =
            feeManager.exposed_computeFeesForNetShares(leverageToken, shares, ExternalAction.Mint);

        uint256 expectedGrossShares = Math.mulDiv(
            Math.mulDiv(shares, MAX_BPS, (MAX_BPS - mintTokenFee), Math.Rounding.Ceil),
            MAX_BPS,
            MAX_BPS - mintTreasuryFee,
            Math.Rounding.Ceil
        );
        assertEq(grossShares, expectedGrossShares);
        // 1 ether * 1e4 / (1e4 - 200) * 1e4 / (1e4 - 400), with rounding up for the divisions
        assertEq(grossShares, 1.062925170068027212 ether);

        uint256 expectedTokenFee = Math.mulDiv(grossShares, mintTokenFee, MAX_BPS, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);
        assertEq(tokenFee, 0.021258503401360545 ether); // 1.062925170068027212 ether * 200 / 1e4, rounded up

        uint256 expectedTreasuryFee = grossShares - tokenFee - shares;
        assertEq(treasuryFee, expectedTreasuryFee);
        assertEq(treasuryFee, 0.041666666666666667 ether); // 1.062925170068027212 ether - 0.021258503401360545 ether - 1 ether

        (grossShares, tokenFee, treasuryFee) =
            feeManager.exposed_computeFeesForNetShares(leverageToken, shares, ExternalAction.Redeem);

        expectedGrossShares = Math.mulDiv(
            Math.mulDiv(shares, MAX_BPS, (MAX_BPS - redeemTokenFee), Math.Rounding.Ceil),
            MAX_BPS,
            MAX_BPS - redeemTreasuryFee,
            Math.Rounding.Ceil
        );
        assertEq(grossShares, expectedGrossShares);
        // 1 ether * 1e4 / (1e4 - 600) * 1e4 / (1e4 - 800), with rounding up for the divisions
        assertEq(grossShares, 1.156336725254394081 ether);

        expectedTokenFee = Math.mulDiv(grossShares, redeemTokenFee, MAX_BPS, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);
        assertEq(tokenFee, 0.069380203515263645 ether); // 1.156336725254394081 ether * 600 / 1e4, rounded up

        expectedTreasuryFee = grossShares - tokenFee - shares;
        assertEq(treasuryFee, expectedTreasuryFee);
        assertEq(treasuryFee, 0.086956521739130436 ether); // 1.156336725254394081 ether - 0.069380203515263645 ether - 1 ether
    }

    function testFuzz_computeTokenFeeForNetShares(
        uint256 shares,
        uint256 mintTokenFee,
        uint256 mintTreasuryFee,
        uint256 redeemTokenFee,
        uint256 redeemTreasuryFee
    ) public {
        shares = bound(shares, 0, type(uint256).max / MAX_BPS_SQUARED);
        mintTokenFee = bound(mintTokenFee, 0, MAX_ACTION_FEE);
        mintTreasuryFee = bound(mintTreasuryFee, 0, MAX_ACTION_FEE);
        redeemTokenFee = bound(redeemTokenFee, 0, MAX_ACTION_FEE);
        redeemTreasuryFee = bound(redeemTreasuryFee, 0, MAX_ACTION_FEE);

        _setLeverageTokenActionFees(mintTokenFee, redeemTokenFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, mintTreasuryFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Redeem, redeemTreasuryFee);

        (uint256 grossShares, uint256 tokenFee, uint256 treasuryFee) =
            feeManager.exposed_computeFeesForNetShares(leverageToken, shares, ExternalAction.Mint);

        uint256 expectedGrossShares = Math.mulDiv(
            Math.mulDiv(shares, MAX_BPS, (MAX_BPS - mintTokenFee), Math.Rounding.Ceil),
            MAX_BPS,
            MAX_BPS - mintTreasuryFee,
            Math.Rounding.Ceil
        );
        assertEq(grossShares, expectedGrossShares);

        uint256 expectedTokenFee =
            Math.min(Math.mulDiv(grossShares, mintTokenFee, MAX_BPS, Math.Rounding.Ceil), grossShares - shares);
        assertEq(tokenFee, expectedTokenFee);

        uint256 expectedTreasuryFee = grossShares - tokenFee - shares;
        assertEq(treasuryFee, expectedTreasuryFee);

        (grossShares, tokenFee, treasuryFee) =
            feeManager.exposed_computeFeesForNetShares(leverageToken, shares, ExternalAction.Redeem);

        expectedGrossShares = Math.mulDiv(
            Math.mulDiv(shares, MAX_BPS, (MAX_BPS - redeemTokenFee), Math.Rounding.Ceil),
            MAX_BPS,
            MAX_BPS - redeemTreasuryFee,
            Math.Rounding.Ceil
        );
        assertEq(grossShares, expectedGrossShares);

        expectedTokenFee =
            Math.min(Math.mulDiv(grossShares, redeemTokenFee, MAX_BPS, Math.Rounding.Ceil), grossShares - shares);
        assertEq(tokenFee, expectedTokenFee);

        expectedTreasuryFee = grossShares - tokenFee - shares;
        assertEq(treasuryFee, expectedTreasuryFee);
    }
}
