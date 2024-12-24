// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library ERC6909Storage {
    /// @dev Struct containing all state for the ERC6909 contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.ERC6909
    struct Layout {
        /// @dev Mapping of id => totalSupply
        mapping(uint256 id => uint256) totalSupplies;
        /// @dev Mapping of owner => id => balance
        mapping(address owner => mapping(uint256 id => uint256 amount)) balances;
        /// @dev Mapping of owner => spender => id => allowance
        mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount))) allowances;
        /// @dev Mapping of owner => spender => operator
        mapping(address owner => mapping(address spender => bool)) isOperator;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.ERC6909")) - 1)) & ~bytes32(uint256(0xff));

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
