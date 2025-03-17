// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancer} from "src/DutchAuctionRebalancer.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {RebalanceAction, TokenTransfer} from "src/types/DataTypes.sol";

/// @notice Wrapper contract that exposes internal functions of DutchAuctionRebalancer for testing
contract DutchAuctionRebalancerHarness is DutchAuctionRebalancer {
    constructor(address owner, ILeverageManager _leverageManager) DutchAuctionRebalancer(owner, _leverageManager) {}

    function exposed_executeRebalanceUp(IStrategy strategy, uint256 collateralAmount, uint256 debtAmount) external {
        _executeRebalanceUp(strategy, collateralAmount, debtAmount);
    }

    function exposed_executeRebalanceDown(IStrategy strategy, uint256 collateralAmount, uint256 debtAmount) external {
        _executeRebalanceDown(strategy, collateralAmount, debtAmount);
    }
}
