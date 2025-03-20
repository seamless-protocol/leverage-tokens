// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";

// Internal imports
import {Strategy} from "src/Strategy.sol";
import {StrategyBaseTest} from "./StrategyBase.t.sol";
import {PermitLib} from "../../utils/PermitLib.sol";

contract PermitTest is StrategyBaseTest {
    using PermitLib for PermitLib.Permit;

    /// @dev Sanity test to ensure that token supports permit
    function testFuzz_permit(PermitLib.Permit memory permit, uint256 privateKey, uint128 blockTimestamp) public {
        vm.warp(blockTimestamp);

        privateKey = bound(privateKey, 1, type(uint32).max);
        permit.owner = vm.addr(privateKey);
        vm.assume(permit.owner != address(0));

        permit.deadline = bound(permit.deadline, block.timestamp, type(uint256).max);
        permit.nonce = strategyToken.nonces(permit.owner);

        PermitLib.Signature memory sig;
        bytes32 digest = PermitLib.getPermitTypedDataHash(permit, address(strategyToken));
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        strategyToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, sig.v, sig.r, sig.s);

        assertEq(strategyToken.nonces(permit.owner), permit.nonce + 1);
        assertEq(strategyToken.allowance(permit.owner, permit.spender), permit.value);
    }
}
