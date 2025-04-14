// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEtherFiL2ModeSyncPoolETH {
    function deposit(address tokenIn, uint256 amountIn, uint256 minAmountOut, address referral)
        external
        payable
        returns (uint256 amountOut);
}
