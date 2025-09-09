// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMulticallExecutor {
    /// @notice Struct containing the target, value, and data for a single external call.
    struct Call {
        address target; // Call target
        uint256 value; // ETH value to send
        bytes data; // Calldata to execute
    }

    /// @notice Executes a multicall and sweeps tokens afterwards
    /// @param calls The calls to execute
    /// @param tokens The tokens to sweep to the sender after executing the calls. ETH is always swept to the sender.
    function multicallAndSweep(Call[] calldata calls, IERC20[] calldata tokens) external;
}
