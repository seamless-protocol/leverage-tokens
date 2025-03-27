// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {RebalanceTest} from "test/integration/LeverageManager/Rebalance.t.sol";
import {DutchAuctionRebalanceAdapter} from "src/rebalance/DutchAuctionRebalanceAdapter.sol";
import {Auction, LeverageTokenState} from "src/types/DataTypes.sol";
import {IDutchAuctionRebalanceAdapter} from "src/interfaces/IDutchAuctionRebalanceAdapter.sol";

contract DutchAuctionTest is RebalanceTest {
    function _prepareOverCollateralizedState() internal {
        // Deposit 10 WETH following target ratio
        uint256 equityToDeposit = 10 * 1e18;
        uint256 collateralToAdd = leverageManager.previewDeposit(ethLong2x, equityToDeposit).collateral;
        _deposit(ethLong2x, user, equityToDeposit, collateralToAdd);

        _moveEthPrice(20_00); // 20% up price movement. Collateral ratio should be 2.4x
    }

    function _prepareUnderCollateralizedState() internal {
        // Deposit 10 WETH following target ratio
        uint256 equityToDeposit = 10 * 1e18;
        uint256 collateralToAdd = leverageManager.previewDeposit(ethLong2x, equityToDeposit).collateral;
        _deposit(ethLong2x, user, equityToDeposit, collateralToAdd);

        _moveEthPrice(-20_00); // 20% down price movement. Collateral ratio should be 1.6x
    }
}
