// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Dependency imports
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {IMulticallExecutor} from "../interfaces/periphery/IMulticallExecutor.sol";

/// @custom:contact security@seamlessprotocol.com
contract MulticallExecutor is IMulticallExecutor {
    /// @inheritdoc IMulticallExecutor
    function multicallAndSweep(Call[] calldata calls, IERC20[] calldata tokens) external {
        for (uint256 i = 0; i < calls.length; i++) {
            // slither-disable-next-line unused-return
            Address.functionCallWithValue(calls[i].target, calls[i].data, calls[i].value);
        }

        // Sweep any remaining tokens to the sender
        uint256 balance;
        for (uint256 i = 0; i < tokens.length; i++) {
            balance = tokens[i].balanceOf(address(this));
            if (balance > 0) {
                SafeERC20.safeTransfer(tokens[i], msg.sender, balance);
            }
        }

        // Sweep any remaining ETH to the sender
        if (address(this).balance > 0) {
            // slither-disable-next-line arbitrary-send-eth
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
