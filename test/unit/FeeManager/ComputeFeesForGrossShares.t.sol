// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ComputeFeesForGrossSharesTest is FeeManagerTest {
    function test_computeFeesForGrossShares() public {
        uint256 shares = 1 ether;
        uint256 mintTokenFee = 0.02e18;
        uint256 mintTreasuryFee = 0.04e18;
        uint256 redeemTokenFee = 0.06e18;
        uint256 redeemTreasuryFee = 0.08e18;

        _setLeverageTokenActionFees(mintTokenFee, redeemTokenFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, mintTreasuryFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Redeem, redeemTreasuryFee);

        (uint256 netShares, uint256 tokenFee, uint256 treasuryFee) =
            feeManager.exposed_computeFeesForGrossShares(leverageToken, shares, ExternalAction.Mint);

        uint256 expectedNetShares = shares * (WAD - mintTokenFee) * (WAD - mintTreasuryFee) / WAD_SQUARED;
        assertEq(netShares, expectedNetShares);
        assertEq(netShares, 0.9408 ether); // 1 ether * 0.98 * 0.96

        uint256 expectedTokenFee = Math.mulDiv(shares, mintTokenFee, WAD, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);
        assertEq(tokenFee, 0.02 ether); // 1 ether * 0.02

        uint256 expectedTreasuryFee = Math.mulDiv(shares - tokenFee, mintTreasuryFee, WAD, Math.Rounding.Ceil);
        assertEq(treasuryFee, expectedTreasuryFee);
        assertEq(treasuryFee, 0.0392 ether); // 1 ether * 0.98 * 0.04

        (netShares, tokenFee, treasuryFee) =
            feeManager.exposed_computeFeesForGrossShares(leverageToken, shares, ExternalAction.Redeem);

        expectedNetShares = shares * (WAD - redeemTokenFee) * (WAD - redeemTreasuryFee) / WAD_SQUARED;
        assertEq(netShares, expectedNetShares);
        assertEq(netShares, 0.8648 ether); // 1 ether * 0.94 * 0.92

        expectedTokenFee = Math.mulDiv(shares, redeemTokenFee, WAD, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);
        assertEq(tokenFee, 0.06 ether); // 1 ether * 0.06

        expectedTreasuryFee = Math.mulDiv(shares - tokenFee, redeemTreasuryFee, WAD, Math.Rounding.Ceil);
        assertEq(treasuryFee, expectedTreasuryFee);
        assertEq(treasuryFee, 0.0752 ether); // 1 ether * 0.94 * 0.08
    }

    function testFuzz_computeFeesForGrossShares(
        uint256 shares,
        uint256 mintTokenFee,
        uint256 mintTreasuryFee,
        uint256 redeemTokenFee,
        uint256 redeemTreasuryFee
    ) public {
        shares = bound(shares, 0, type(uint256).max / WAD_SQUARED);
        mintTokenFee = bound(mintTokenFee, 0, MAX_ACTION_FEE);
        mintTreasuryFee = bound(mintTreasuryFee, 0, MAX_ACTION_FEE);
        redeemTokenFee = bound(redeemTokenFee, 0, MAX_ACTION_FEE);
        redeemTreasuryFee = bound(redeemTreasuryFee, 0, MAX_ACTION_FEE);

        _setLeverageTokenActionFees(mintTokenFee, redeemTokenFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, mintTreasuryFee);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Redeem, redeemTreasuryFee);

        (uint256 netShares, uint256 tokenFee, uint256 treasuryFee) =
            feeManager.exposed_computeFeesForGrossShares(leverageToken, shares, ExternalAction.Mint);

        uint256 expectedTokenFee = Math.mulDiv(shares, mintTokenFee, WAD, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);

        uint256 expectedTreasuryFee = Math.mulDiv(shares - tokenFee, mintTreasuryFee, WAD, Math.Rounding.Ceil);
        assertEq(treasuryFee, expectedTreasuryFee);

        uint256 expectedNetShares = shares - tokenFee - treasuryFee;
        assertEq(netShares, expectedNetShares);

        (netShares, tokenFee, treasuryFee) =
            feeManager.exposed_computeFeesForGrossShares(leverageToken, shares, ExternalAction.Redeem);

        expectedTokenFee = Math.mulDiv(shares, redeemTokenFee, WAD, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);

        expectedTreasuryFee = Math.mulDiv(shares - tokenFee, redeemTreasuryFee, WAD, Math.Rounding.Ceil);
        assertEq(treasuryFee, expectedTreasuryFee);

        expectedNetShares = shares - tokenFee - treasuryFee;
        assertEq(netShares, expectedNetShares);
    }
}
