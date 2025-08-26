// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

/// @dev This implementation is copied from the original version implemented by Morpho
/// https://github.com/morpho-org/bundler3/blob/4887f33299ba6e60b54a51237b16e7392dceeb97/src/mocks/AugustusMock.sol
contract MockAugustus is Test {
    uint256 public toGive = type(uint256).max;
    uint256 public toTake = type(uint256).max;

    function setToGive(uint256 amount) external {
        toGive = amount;
    }

    function setToTake(uint256 amount) external {
        toTake = amount;
    }

    function mockBuy(address srcToken, address destToken, uint256, uint256 toAmount) external {
        if (toGive != type(uint256).max) toAmount = toGive;
        uint256 fromAmount = toTake != type(uint256).max ? toTake : toAmount;

        IERC20(srcToken).transferFrom(msg.sender, address(this), fromAmount);
        deal(address(destToken), address(this), toAmount);
        IERC20(destToken).transfer(msg.sender, toAmount);

        toGive = type(uint256).max;
        toTake = type(uint256).max;
    }

    function mockSell(address srcToken, address destToken, uint256 fromAmount, uint256) external {
        if (toTake != type(uint256).max) fromAmount = toTake;
        uint256 toAmount = toGive != type(uint256).max ? toGive : fromAmount;

        IERC20(srcToken).transferFrom(msg.sender, address(this), fromAmount);
        deal(address(destToken), address(this), toAmount);
        IERC20(destToken).transfer(msg.sender, toAmount);

        toGive = type(uint256).max;
        toTake = type(uint256).max;
    }
}
