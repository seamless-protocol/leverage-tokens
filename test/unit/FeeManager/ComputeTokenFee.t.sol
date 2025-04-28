// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ComputeTokenFeeTest is FeeManagerTest {
    function test_computeTokenFee_Mint() public {
        ExternalAction action = ExternalAction.Mint;
        uint256 equity = 1 ether;
        uint256 mintTokenFee = 200;
        uint256 redeemTokenFee = 400;
        _setFees(mintTokenFee, redeemTokenFee);

        (uint256 equityForSharesAfterFees, uint256 tokenFee) =
            feeManager.exposed_computeTokenFee(leverageToken, equity, action);

        uint256 expectedTokenFee = Math.mulDiv(equity, mintTokenFee, MAX_FEE, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);

        assertEq(equityForSharesAfterFees, equity - expectedTokenFee);
    }

    function test_computeTokenFee_Redeem() public {
        ExternalAction action = ExternalAction.Redeem;
        uint256 equity = 1 ether;
        uint256 mintTokenFee = 200;
        uint256 redeemTokenFee = 400;
        _setFees(mintTokenFee, redeemTokenFee);

        (uint256 equityForSharesAfterFees, uint256 tokenFee) =
            feeManager.exposed_computeTokenFee(leverageToken, equity, action);

        uint256 expectedTokenFee = Math.mulDiv(equity, redeemTokenFee, MAX_FEE, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);

        assertEq(equityForSharesAfterFees, equity + expectedTokenFee);
    }

    function testFuzz_computeTokenFee(uint128 equity, uint256 mintTokenFee, uint256 redeemTokenFee) public {
        ExternalAction action = ExternalAction.Mint;
        mintTokenFee = bound(mintTokenFee, 0, MAX_FEE);
        redeemTokenFee = bound(redeemTokenFee, 0, MAX_FEE);
        _setFees(mintTokenFee, redeemTokenFee);

        (uint256 equityForSharesAfterFees, uint256 tokenFee) =
            feeManager.exposed_computeTokenFee(leverageToken, equity, action);

        uint256 expectedTokenFee = Math.mulDiv(
            equity, action == ExternalAction.Mint ? mintTokenFee : redeemTokenFee, MAX_FEE, Math.Rounding.Ceil
        );
        assertEq(tokenFee, expectedTokenFee);

        uint256 expectedEquityForSharesAfterFees =
            action == ExternalAction.Mint ? equity - expectedTokenFee : equity + expectedTokenFee;
        assertEq(equityForSharesAfterFees, expectedEquityForSharesAfterFees);

        assertLe(tokenFee, equity);
        assertLe(expectedEquityForSharesAfterFees, equity);
    }

    function _setFees(uint256 mintTokenFee, uint256 redeemTokenFee) internal {
        vm.startPrank(feeManagerRole);
        feeManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Mint, mintTokenFee);
        feeManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Redeem, redeemTokenFee);
        vm.stopPrank();
    }
}
