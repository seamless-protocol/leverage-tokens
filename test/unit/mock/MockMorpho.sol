// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {MarketParams, Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMorpho {
    mapping(Id => MarketParams) public idToMarketParams;

    constructor(Id marketId, MarketParams memory marketParams) {
        idToMarketParams[marketId] = marketParams;
    }

    function mockSetMarketParams(Id marketId, MarketParams memory marketParams) external {
        idToMarketParams[marketId] = marketParams;
    }

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256, /* shares */
        address, /* onBehalf */
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed) {
        // Mocked return values that are not used in test.
        assetsBorrowed = assets;
        sharesBorrowed = assets;

        IERC20(marketParams.loanToken).transfer(receiver, assets);
    }

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256, /* shares */
        address, /* onBehalf */
        bytes memory /* data */
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid) {
        // Mocked return values that are not used in test.
        assetsRepaid = assets;
        sharesRepaid = assets;

        IERC20(marketParams.loanToken).transferFrom(msg.sender, address(this), assets);
    }

    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address, /* onBehalf */
        bytes memory /* data */
    ) external {
        IERC20(marketParams.collateralToken).transferFrom(msg.sender, address(this), assets);
    }

    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address, /* onBehalf */
        address receiver
    ) external {
        IERC20(marketParams.collateralToken).transfer(receiver, assets);
    }
}
