// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Dependency imports
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";

contract Strategy is Initializable, ERC20Upgradeable, OwnableUpgradeable, IStrategy {
    function initialize(address owner, string memory _name, string memory _symbol) external initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init(owner);
    }

    /// @inheritdoc IStrategy
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc IStrategy
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
