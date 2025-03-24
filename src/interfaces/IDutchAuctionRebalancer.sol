// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategy} from "./IStrategy.sol";
import {ILeverageManager} from "./ILeverageManager.sol";
import {Auction} from "src/types/DataTypes.sol";

interface IDutchAuctionRebalancer {
    /// @notice Error thrown when auction is not valid
    error AuctionNotValid();

    /// @notice Error thrown when auction is still valid
    error AuctionStillValid();

    /// @notice Error thrown when strategy is not eligible for rebalance
    error StrategyNotEligibleForRebalance();

    /// @notice Error thrown when auction duration is zero
    error InvalidAuctionDuration();

    /// @notice Error thrown when minimum price multiplier is higher than initial price multiplier
    error MinPriceMultiplierTooHigh();

    /// @notice Event emitted when new auction is created
    event AuctionCreated(IStrategy indexed strategy, Auction auction);

    /// @notice Event emitted when auction is taken
    event Take(IStrategy indexed strategy, address indexed taker, uint256 amountIn, uint256 amountOut);

    /// @notice Event emitted when auction ends
    event AuctionEnded(IStrategy indexed strategy);

    /// @notice Event emitted when auction duration is updated
    event AuctionDurationSet(IStrategy indexed strategy, uint256 newDuration);

    /// @notice Event emitted when initial price multiplier is updated
    event InitialPriceMultiplierSet(IStrategy indexed strategy, uint256 newMultiplier);

    /// @notice Event emitted when minimum price multiplier is updated
    event MinPriceMultiplierSet(IStrategy indexed strategy, uint256 newMultiplier);

    /// @notice Returns leverage manager
    /// @return leverageManager Leverage manager
    function leverageManager() external view returns (ILeverageManager leverageManager);

    /// @notice Returns auction duration
    /// @param strategy Strategy to get duration for
    /// @return auctionDuration Auction duration
    function auctionDuration(IStrategy strategy) external view returns (uint256 auctionDuration);

    /// @notice Returns initial price multiplier
    /// @param strategy Strategy to get multiplier for
    /// @return multiplier Initial price multiplier
    function initialPriceMultiplier(IStrategy strategy) external view returns (uint256 multiplier);

    /// @notice Returns minimum price multiplier
    /// @param strategy Strategy to get multiplier for
    /// @return multiplier Minimum price multiplier
    function minPriceMultiplier(IStrategy strategy) external view returns (uint256 multiplier);

    /// @notice Returns strategy rebalance status
    /// @param strategy Strategy to check
    /// @return isEligibleForRebalance Whether strategy is eligible for rebalance
    /// @return isOverCollateralized Whether strategy is over-collateralized
    function getStrategyRebalanceStatus(IStrategy strategy)
        external
        view
        returns (bool isEligibleForRebalance, bool isOverCollateralized);

    /// @notice Returns whether auction is valid
    /// @param strategy Strategy to check
    /// @return isValid Whether auction is valid
    function isAuctionValid(IStrategy strategy) external view returns (bool isValid);

    /// @notice Returns current auction multiplier
    /// @param strategy Strategy to get multiplier for
    /// @return multiplier Current auction multiplier
    /// @dev This module uses exponential approximation (1-x)^4 to calculate the current auction multiplier
    function getCurrentAuctionMultiplier(IStrategy strategy) external view returns (uint256 multiplier);

    /// @notice Returns amount of tokens to provide for given amount of tokens to receive
    /// @param strategy Strategy to calculate for
    /// @param amountOut Amount of tokens to receive
    /// @return amountIn Amount of tokens to provide
    /// @dev If there is no valid auction in the current block, this function will still return a value based on the most recent auction
    function getAmountIn(IStrategy strategy, uint256 amountOut) external view returns (uint256 amountIn);

    /// @notice Creates new auction for strategy that needs rebalancing
    /// @param strategy Strategy to create auction for
    function createAuction(IStrategy strategy) external;

    /// @notice Ends auction for strategy
    /// @param strategy Strategy to end auction for
    function endAuction(IStrategy strategy) external;

    /// @notice Takes part in auction at current discounted price
    /// @param strategy Strategy to take auction for
    /// @param amountOut Amount of tokens to receive
    function take(IStrategy strategy, uint256 amountOut) external;

    /// @notice Sets the auction duration
    /// @param strategy Strategy to set duration for
    /// @param newDuration New duration in seconds
    function setAuctionDuration(IStrategy strategy, uint256 newDuration) external;

    /// @notice Sets the initial price multiplier
    /// @param strategy Strategy to set multiplier for
    /// @param newMultiplier New multiplier
    function setInitialPriceMultiplier(IStrategy strategy, uint256 newMultiplier) external;

    /// @notice Sets the minimum multiplier
    /// @param strategy Strategy to set multiplier for
    /// @param newMultiplier New multiplier
    function setMinPriceMultiplier(IStrategy strategy, uint256 newMultiplier) external;
}
