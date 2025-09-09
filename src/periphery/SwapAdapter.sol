// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ISwapAdapter} from "../interfaces/periphery/ISwapAdapter.sol";

contract SwapAdapter is ISwapAdapter {
    /// @inheritdoc ISwapAdapter
    function swapWithMulticall(Call[] calldata calls, IERC20 from, IERC20 to) external {
        for (uint256 i = 0; i < calls.length; i++) {
            // slither-disable-next-line unused-return
            Address.functionCallWithValue(calls[i].target, calls[i].data, calls[i].value);
        }

        // Sweep any remaining tokens to the sender
        uint256 fromBalance = from.balanceOf(address(this));
        uint256 toBalance = to.balanceOf(address(this));
        if (fromBalance > 0) {
            SafeERC20.safeTransfer(from, msg.sender, fromBalance);
        }
        if (toBalance > 0) {
            SafeERC20.safeTransfer(to, msg.sender, toBalance);
        }

        // Sweep any remaining ETH to the sender
        if (address(this).balance > 0) {
            // slither-disable-next-line arbitrary-send-eth
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
