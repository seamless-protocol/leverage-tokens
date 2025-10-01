// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMulticall3} from "src/interfaces/IMulticall3.sol";
import {IMulticallExecutor} from "src/interfaces/periphery/IMulticallExecutor.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

import {console} from "forge-std/console.sol";

contract SignedDelegation is IntegrationTestBase {
    // Alice's address and private key (EOA with no initial contract code).
    address payable ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // Bob's address (Bob will execute transactions on Alice's behalf).
    address constant BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function testFork_signed_delegation_deposit_multicall3() public {
        uint256 collateralToDeposit = 0.1e8; // 0.1 cbBTC
        deal(address(CBBTC), ALICE_ADDRESS, collateralToDeposit); // Alice's address must have the collateral to deposit

        // Using signed delegation to approve leveragemanager to spend collateral and debt assets
        IMulticall3.Call[] memory calls = new IMulticall3.Call[](3);
        calls[0] = IMulticall3.Call({
            target: address(CBBTC),
            callData: abi.encodeWithSelector(CBBTC.approve.selector, address(leverageManager), collateralToDeposit)
        });
        calls[1] = IMulticall3.Call({
            target: address(leverageManager),
            callData: abi.encodeWithSelector(ILeverageManager.deposit.selector, leverageToken, collateralToDeposit, 0)
        });
        calls[2] = IMulticall3.Call({
            target: address(leverageToken),
            callData: abi.encodeWithSelector(leverageToken.transfer.selector, BOB_ADDRESS, 0.05e18)
        });

        vm.signAndAttachDelegation(MULTICALL3_ADDRESS, ALICE_PK, vm.getNonce(ALICE_ADDRESS));

        require(ALICE_ADDRESS.code.length > 0, "Alice should have code");

        vm.prank(BOB_ADDRESS);
        IMulticall3(ALICE_ADDRESS).aggregate(calls);

        // Reverts because Bob maliciously transfers the LTs to themselves
        assertEq(leverageToken.balanceOf(BOB_ADDRESS), 0, "Bob should have no balance of the leverage token");
    }
}
