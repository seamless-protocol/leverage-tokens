// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ERC6909} from "src/ERC6909.sol";

contract ERC6909Harness is ERC6909 {
    function exposed_mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount);
    }

    function exposed_burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }
}
