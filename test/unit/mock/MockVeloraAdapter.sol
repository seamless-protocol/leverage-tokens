// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";

contract MockVeloraAdapter is Test {
    mapping(address token => uint256 mockedBalance) public mockedTransferBalances;
    mapping(address srcToken => uint256 mockedSrcAmount) public mockedBuy;

    function mockNextTransfer(address token, uint256 mockedBalance) public {
        mockedTransferBalances[token] = mockedBalance;
    }

    function mockNextBuy(address srcToken, uint256 mockedSrcAmount) public {
        mockedBuy[srcToken] = mockedSrcAmount;
    }

    function erc20Transfer(address token, address receiver, uint256 amount) public {
        uint256 balance = mockedTransferBalances[token];
        deal(token, address(this), balance);

        if (amount == type(uint256).max) {
            IERC20(token).transfer(receiver, balance);
        } else {
            mockedTransferBalances[token] = balance - amount;
            IERC20(token).transfer(receiver, amount);
        }
    }

    function buy(
        address, /* augustus */
        bytes memory, /* callData */
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        IVeloraAdapter.Offsets calldata, /* offsets */
        address receiver
    ) public {
        uint256 requiredSrcAmount = mockedBuy[srcToken];
        uint256 balance = IERC20(srcToken).balanceOf(address(this));

        if (balance < requiredSrcAmount) {
            revert("MockVeloraAdapter: Insufficient balance for buy");
        }

        deal(destToken, address(this), newDestAmount);
        IERC20(destToken).transfer(receiver, newDestAmount);
    }
}
