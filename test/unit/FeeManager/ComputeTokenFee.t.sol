// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ComputeTokenFeeTest is FeeManagerTest {
    function test_computeTokenFee_Deposit() public {
        ExternalAction action = ExternalAction.Deposit;
        uint256 equity = 1 ether;
        uint256 depositTokenFee = 200;
        uint256 withdrawTokenFee = 400;
        _setFees(depositTokenFee, withdrawTokenFee);

        (uint256 equityForSharesAfterFees, uint256 tokenFee) =
            feeManager.exposed_computeTokenFee(leverageToken, equity, action);

        uint256 expectedTokenFee = Math.mulDiv(equity, depositTokenFee, MAX_FEE, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);

        assertEq(equityForSharesAfterFees, equity - expectedTokenFee);
    }

    function test_computeTokenFee_Withdraw() public {
        ExternalAction action = ExternalAction.Withdraw;
        uint256 equity = 1 ether;
        uint256 depositTokenFee = 200;
        uint256 withdrawTokenFee = 400;
        _setFees(depositTokenFee, withdrawTokenFee);

        (uint256 equityForSharesAfterFees, uint256 tokenFee) =
            feeManager.exposed_computeTokenFee(leverageToken, equity, action);

        uint256 expectedTokenFee = Math.mulDiv(equity, withdrawTokenFee, MAX_FEE, Math.Rounding.Ceil);
        assertEq(tokenFee, expectedTokenFee);

        assertEq(equityForSharesAfterFees, equity + expectedTokenFee);
    }

    function testFuzz_computeTokenFee(uint128 equity, uint256 depositTokenFee, uint256 withdrawTokenFee) public {
        ExternalAction action = ExternalAction.Deposit;
        depositTokenFee = bound(depositTokenFee, 0, MAX_FEE);
        withdrawTokenFee = bound(withdrawTokenFee, 0, MAX_FEE);
        _setFees(depositTokenFee, withdrawTokenFee);

        (uint256 equityForSharesAfterFees, uint256 tokenFee) =
            feeManager.exposed_computeTokenFee(leverageToken, equity, action);

        uint256 expectedTokenFee = Math.mulDiv(
            equity, action == ExternalAction.Deposit ? depositTokenFee : withdrawTokenFee, MAX_FEE, Math.Rounding.Ceil
        );
        assertEq(tokenFee, expectedTokenFee);

        uint256 expectedEquityForSharesAfterFees =
            action == ExternalAction.Deposit ? equity - expectedTokenFee : equity + expectedTokenFee;
        assertEq(equityForSharesAfterFees, expectedEquityForSharesAfterFees);

        assertLe(tokenFee, equity);
        assertLe(expectedEquityForSharesAfterFees, equity);
    }

    function _setFees(uint256 depositTokenFee, uint256 withdrawTokenFee) internal {
        vm.startPrank(feeManagerRole);
        feeManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Deposit, depositTokenFee);
        feeManager.exposed_setLeverageTokenActionFee(leverageToken, ExternalAction.Withdraw, withdrawTokenFee);
        vm.stopPrank();
    }
}
