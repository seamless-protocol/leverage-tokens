// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";

contract MockVeloraAdapter is Test {
    mapping(address srcToken => uint256 mockedSrcAmount) public mockedBuy;

    function mockNextBuy(address srcToken, uint256 mockedSrcAmount) public {
        mockedBuy[srcToken] = mockedSrcAmount;
    }

    function buy(
        address, /* augustus */
        bytes memory, /* callData */
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        IVeloraAdapter.Offsets calldata, /* offsets */
        address receiver
    ) public returns (uint256) {
        uint256 requiredSrcAmount = mockedBuy[srcToken];
        uint256 balance = IERC20(srcToken).balanceOf(address(this));

        if (balance < requiredSrcAmount) {
            revert("MockVeloraAdapter: Insufficient balance for buy");
        }

        deal(destToken, address(this), newDestAmount);
        IERC20(destToken).transfer(receiver, newDestAmount);

        uint256 excessSrcAmount = balance - requiredSrcAmount;
        IERC20(srcToken).transfer(msg.sender, excessSrcAmount);

        return excessSrcAmount;
    }
}
