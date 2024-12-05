// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library FeeManagerStorage {
    /// @dev Struct that contains fee configuration for one strategy
    struct StrategyFeeConfig {
        /// @dev Fee on leveraged amount on deposit action
        uint8 depositFee;
        /// @dev Fee on leveraged amount on withdraw action
        uint8 withdrawFee;
        /// @dev Fee on leveraged amount on compound action
        uint8 compoundFee;
    }

    /// @dev Struct containing all state for the FeeManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.FeeManager
    struct Layout {
        /// @dev Treasury address that receives all the fees
        address treasury;
        /// @dev Strategy address => Config for strategy
        mapping(address strategy => StrategyFeeConfig) strategyFeeConfig;
    }

    //TODO: Fix this slot
    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT = 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
