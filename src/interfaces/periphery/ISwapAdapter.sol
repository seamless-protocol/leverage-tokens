// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISwapAdapter {
    /// @notice Struct containing the target, value, and data for a single external call.
    struct Call {
        address target; // Call target
        uint256 value; // ETH value to send
        bytes data; // Calldata to execute
    }

    /// @notice Swaps tokens with a multicall
    /// @param calls The calls to execute for the swap
    /// @param from The token to swap from
    /// @param to The token to swap to
    /// @dev Any balance of from and to token in the SwapAdapter after the execution of the calls is sent to the sender
    /// @dev Any balance of ETH in the SwapAdapter after the execution of the calls is sent to the sender
    function swapWithMulticall(Call[] calldata calls, IERC20 from, IERC20 to) external;
}
