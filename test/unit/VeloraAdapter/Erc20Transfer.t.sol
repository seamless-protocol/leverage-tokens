// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VeloraAdapterTest} from "./VeloraAdapter.t.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";

contract Erc20TransferTest is VeloraAdapterTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_erc20Transfer_RevertIf_ZeroAddressReceiver(address token, uint256 amount) public {
        vm.expectRevert("ZERO_ADDRESS_RECEIVER");
        veloraAdapter.erc20Transfer(token, address(0), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_erc20Transfer_RevertIf_AdapterAddressReceiver(address token, uint256 amount) public {
        vm.expectRevert("ADAPTER_ADDRESS_RECEIVER");
        veloraAdapter.erc20Transfer(token, address(veloraAdapter), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_erc20Transfer_RevertIf_ZeroAmount(address token, address receiver) public {
        vm.expectRevert("ZERO_AMOUNT");
        veloraAdapter.erc20Transfer(token, receiver, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_erc20Transfer_TransferMaxAmount(address receiver, uint256 amount) public {
        vm.assume(receiver != address(0) && receiver != address(veloraAdapter));

        deal(address(collateralToken), address(veloraAdapter), amount);
        veloraAdapter.erc20Transfer(address(collateralToken), receiver, type(uint256).max);
        assertEq(collateralToken.balanceOf(receiver), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_erc20Transfer_TransferAmount(address receiver, uint256 amount) public {
        vm.assume(receiver != address(0) && receiver != address(veloraAdapter));
        amount = bound(amount, 1, type(uint256).max - 1);

        deal(address(collateralToken), address(veloraAdapter), amount);
        veloraAdapter.erc20Transfer(address(collateralToken), receiver, amount);
        assertEq(collateralToken.balanceOf(receiver), amount);
    }
}
