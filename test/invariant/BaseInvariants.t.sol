// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

contract BaseInvariants is InvariantTestBase {
    function invariant_base() public view {
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore =
            leverageManagerHandler.getLeverageTokenStateBefore();

        if (stateBefore.actionType == LeverageManagerHandler.ActionType.Initial) {
            return;
        }

        LeverageTokenState memory state = leverageManager.getLeverageTokenState(stateBefore.leverageToken);

        if (state.debt != 0) {
            uint256 totalSupplyAfter = stateBefore.leverageToken.totalSupply();

            assertGt(
                totalSupplyAfter,
                0,
                "Invariant Violated: The total supply of the leverage token must be greater than zero if the equity is not zero."
            );
        }
    }
}
