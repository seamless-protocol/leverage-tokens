// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {MarketParams, Id} from "src/vendor/morpho/IMorpho.sol";

contract MockMorpho {

    mapping(Id => MarketParams) private idToMarketParams;

    constructor(Id marketId, MarketParams memory marketParams) {
        idToMarketParams[marketId] = marketParams;
    }

    function mockSetMarketParams(Id marketId, MarketParams memory marketParams) external {
        idToMarketParams[marketId] = marketParams;
    }
}
