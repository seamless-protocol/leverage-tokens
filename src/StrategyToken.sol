// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Dependency imports
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {IStrategyToken} from "src/interfaces/IStrategyToken.sol";

contract StrategyToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, IStrategyToken {
    function initialize(address owner, string memory _name, string memory _symbol) external initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init(owner);
    }

    /// @inheritdoc IStrategyToken
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc IStrategyToken
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
