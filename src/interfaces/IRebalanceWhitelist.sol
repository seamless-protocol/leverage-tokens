// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IRebalanceWhitelist {
    /// @notice Returns if given user is allowed to rebalance certain strategy
    /// @param strategy Strategy to check rebalancer for
    /// @param user User to check eligibility for
    /// @return isAllowed Is allowed to rebalance
    /// @dev Leverage manager calls this function in case manager wants to enforce different rebalance mechanisms in external contract
    function isAllowedToRebalance(address strategy, address user) external view returns (bool isAllowed);
}
