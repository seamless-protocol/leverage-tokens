// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ComputeTokenFeeForExactSharesTest is FeeManagerTest {
    function testFuzz_computeTokenFeeForExactShares_Mint(uint256 mintTokenFee, uint256 mintTreasuryFee) public {
        mintTokenFee = bound(mintTokenFee, 0, MAX_ACTION_FEE);
        mintTreasuryFee = bound(mintTreasuryFee, 0, MAX_ACTION_FEE);

        ExternalAction action = ExternalAction.Mint;
        uint256 shares = 1 ether;
        _setLeverageTokenActionFees(mintTokenFee, 0);
        _setTreasuryActionFee(feeManagerRole, ExternalAction.Mint, mintTreasuryFee);

        (uint256 grossShares, uint256 tokenFee, uint256 treasuryFee) =
            feeManager.exposed_computeTokenFeeForExactShares(leverageToken, shares, action);

        uint256 expectedGrossShares = Math.mulDiv(
            shares, BASE_FEE_SQUARED, (BASE_FEE - mintTokenFee) * (BASE_FEE - mintTreasuryFee), Math.Rounding.Ceil
        );
        assertEq(grossShares, expectedGrossShares);

        uint256 expectedTokenFee =
            Math.min(Math.mulDiv(grossShares, mintTokenFee, BASE_FEE, Math.Rounding.Ceil), grossShares - shares);
        assertEq(tokenFee, expectedTokenFee);

        uint256 expectedTreasuryFee = grossShares - tokenFee - shares;
        assertEq(treasuryFee, expectedTreasuryFee);
    }
}
