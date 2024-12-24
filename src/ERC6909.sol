// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC6909} from "./interfaces/IERC6909.sol";
import {ERC6909Storage as Storage} from "./storage/ERC6909Storage.sol";

contract ERC6909 is IERC6909 {
    /// @inheritdoc IERC6909
    function totalSupply(uint256 id) public view returns (uint256 supply) {
        return Storage.layout().totalSupplies[id];
    }

    /// @inheritdoc IERC6909
    function balanceOf(address owner, uint256 id) public view returns (uint256 balance) {
        return Storage.layout().balances[owner][id];
    }

    /// @inheritdoc IERC6909
    function isOperator(address owner, address spender) public view returns (bool approved) {
        return Storage.layout().isOperator[owner][spender];
    }

    /// @inheritdoc IERC6909
    function allowance(address owner, address spender, uint256 id) public view returns (uint256 amount) {
        return Storage.layout().allowances[owner][spender][id];
    }

    /// @inheritdoc IERC6909
    function setOperator(address spender, bool approved) external returns (bool success) {
        Storage.layout().isOperator[msg.sender][spender] = approved;
        emit OperatorSet(msg.sender, spender, approved);
        return true;
    }

    /// @inheritdoc IERC6909
    function approve(address spender, uint256 id, uint256 amount) external returns (bool success) {
        Storage.layout().allowances[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool supported) {
        return interfaceId == type(IERC6909).interfaceId;
    }

    /// @inheritdoc IERC6909
    function transfer(address receiver, uint256 id, uint256 amount) public returns (bool success) {
        return _transfer(msg.sender, receiver, id, amount);
    }

    /// @inheritdoc IERC6909
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool success) {
        Storage.Layout storage $ = Storage.layout();

        if (sender != msg.sender && !isOperator(sender, msg.sender)) {
            uint256 senderAllowance = allowance(sender, msg.sender, id);

            if (senderAllowance < amount) {
                revert InsufficientPermission(msg.sender, id);
            }

            if (senderAllowance != type(uint256).max) {
                $.allowances[sender][msg.sender][id] = senderAllowance - amount;
            }
        }

        return _transfer(sender, receiver, id, amount);
    }

    function _transfer(address from, address to, uint256 id, uint256 amount) internal returns (bool success) {
        if (balanceOf(from, id) < amount) {
            revert InsufficientBalance(from, id);
        }

        Storage.Layout storage $ = Storage.layout();
        $.balances[from][id] -= amount;
        $.balances[to][id] += amount;

        emit Transfer(msg.sender, from, to, id, amount);
        return true;
    }

    function _mint(address owner, uint256 id, uint256 amount) internal {
        Storage.Layout storage $ = Storage.layout();

        $.balances[owner][id] += amount;
        $.totalSupplies[id] += amount;

        emit Transfer(msg.sender, address(0), owner, id, amount);
    }

    function _burn(address owner, uint256 id, uint256 amount) internal {
        Storage.Layout storage $ = Storage.layout();

        if (balanceOf(owner, id) < amount) {
            revert InsufficientBalance(owner, id);
        }

        $.balances[owner][id] -= amount;
        $.totalSupplies[id] -= amount;

        emit Transfer(msg.sender, owner, address(0), id, amount);
    }
}
