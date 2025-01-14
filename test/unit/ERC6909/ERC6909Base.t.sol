// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Local imports
import {ERC6909Harness} from "test/unit/ERC6909/harness/ERC6909Harness.sol";

contract ERC6909Base is Test {
    ERC6909Harness public erc6909;

    function setUp() public virtual {
        erc6909 = new ERC6909Harness();
    }

    function _mint(address to, uint256 id, uint256 amount) internal {
        erc6909.exposed_mint(to, id, amount);
    }
}
