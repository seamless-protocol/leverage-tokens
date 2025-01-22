// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

struct OneInchSwapDescription {
    address srcToken;
    address dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
}

interface IOneInchAggregationExecutor {
    /// @notice propagates information about original msg.sender and executes arbitrary data
    function execute(address msgSender) external payable returns (uint256); // 0x4b64e492
}

interface IOneInchAggregationRouterV6 {
    /// @notice Performs a swap, delegating all calls encoded in `data` to `_executor`.
    /// @dev router keeps 1 wei of every token on the contract balance for gas optimisations reasons. This affects first swap of every token by leaving 1 wei on the contract.
    /// @param _executor Aggregation _executor that executes calls described in `data`
    /// @param _desc Swap description
    /// @param _data Encoded calls that `caller` should execute in between of swaps
    /// @return returnAmount_ Resulting token amount
    /// @return spentAmount_ Source token amount
    function swap(IOneInchAggregationExecutor _executor, OneInchSwapDescription calldata _desc, bytes calldata _data)
        external
        payable
        returns (uint256 returnAmount_, uint256 spentAmount_);
}
