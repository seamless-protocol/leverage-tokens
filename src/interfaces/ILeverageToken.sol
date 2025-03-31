// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILeverageToken is IERC20 {
    /// @notice Mints new tokens to the specified address
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    /// @dev Only the owner can call this function. Owner should be the LeverageManager contract
    function mint(address to, uint256 amount) external;

    /// @notice Burns tokens from the specified address
    /// @param from The address to burn tokens from
    /// @param amount The amount of tokens to burn
    /// @dev Only the owner can call this function. Owner should be the LeverageManager contract
    function burn(address from, uint256 amount) external;
}
