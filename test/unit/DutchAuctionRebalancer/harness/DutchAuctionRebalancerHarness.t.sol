// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancer} from "src/rebalance/DutchAuctionRebalancer.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {RebalanceAction, TokenTransfer} from "src/types/DataTypes.sol";

/// @notice Wrapper contract that exposes internal functions of DutchAuctionRebalancer for testing
contract DutchAuctionRebalancerHarness is DutchAuctionRebalancer {
    constructor(address owner, ILeverageManager _leverageManager) DutchAuctionRebalancer(owner, _leverageManager) {}

    function exposed_executeRebalanceUp(ILeverageToken token, uint256 collateralAmount, uint256 debtAmount) external {
        _executeRebalanceUp(token, collateralAmount, debtAmount);
    }

    function exposed_executeRebalanceDown(ILeverageToken token, uint256 collateralAmount, uint256 debtAmount)
        external
    {
        _executeRebalanceDown(token, collateralAmount, debtAmount);
    }
}
