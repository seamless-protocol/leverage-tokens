// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC6909} from "src/ERC6909.sol";

contract ERC6909Harness is ERC6909 {
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }
}
