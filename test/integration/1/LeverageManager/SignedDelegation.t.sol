// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMulticallExecutor} from "src/interfaces/periphery/IMulticallExecutor.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

import {console} from "forge-std/console.sol";

contract SignedDelegation is IntegrationTestBase {
    // Alice's address and private key (EOA with no initial contract code).
    address payable ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // Bob's address (Bob will execute transactions on Alice's behalf).
    address constant BOB_ADDRESS = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function testFork_signed_delegation_deposit() public {
        uint256 collateralToDeposit = 0.1e8; // 0.1 cbBTC
        deal(address(CBBTC), ALICE_ADDRESS, collateralToDeposit);

        // Using signed delegation to approve leveragemanager to spend collateral and debt assets
        IMulticallExecutor.Call[] memory calls = new IMulticallExecutor.Call[](2);
        calls[0] = IMulticallExecutor.Call({
            target: address(CBBTC),
            value: 0,
            data: abi.encodeWithSelector(CBBTC.approve.selector, address(leverageManager), collateralToDeposit)
        });
        calls[1] = IMulticallExecutor.Call({
            target: address(leverageManager),
            value: 0,
            data: abi.encodeWithSelector(
                ILeverageManager.deposit.selector, leverageToken, collateralToDeposit, 0
            )
        });

        // Alice signs and attaches the delegation in one step (eliminating the need for separate signing).
        vm.signAndAttachDelegation(address(multicallExecutor), ALICE_PK, vm.getNonce(ALICE_ADDRESS));

        // Verify that Alice's account now behaves as a smart contract.
        bytes memory code = address(ALICE_ADDRESS).code;
        assertGt(code.length, 0, "no code written to Alice");

        IERC20[] memory sweepTokens = new IERC20[](2);
        sweepTokens[0] = leverageToken;
        sweepTokens[1] = USDC;

        vm.prank(BOB_ADDRESS);
        IMulticallExecutor(ALICE_ADDRESS).multicallAndSweep(calls, sweepTokens);

        // Reverts because MulticallAndSweep uses Alice's cbBTC to mint LTs and sends them to Bob
        assertEq(leverageToken.balanceOf(BOB_ADDRESS), 0, "Bob should have no balance of the leverage token");
    }
}
