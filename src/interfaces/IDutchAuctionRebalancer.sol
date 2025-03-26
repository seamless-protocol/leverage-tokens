// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILeverageToken} from "./ILeverageToken.sol";
import {ILeverageManager} from "./ILeverageManager.sol";
import {Auction} from "src/types/DataTypes.sol";

interface IDutchAuctionRebalancer {
    /// @notice Error thrown when auction is not valid
    error AuctionNotValid();

    /// @notice Error thrown when auction is still valid
    error AuctionStillValid();

    /// @notice Error thrown when leverage token is not eligible for rebalance
    error LeverageTokenNotEligibleForRebalance();

    /// @notice Error thrown when auction duration is zero
    error InvalidAuctionDuration();

    /// @notice Error thrown when minimum price multiplier is higher than initial price multiplier
    error MinPriceMultiplierTooHigh();

    /// @notice Event emitted when new auction is created
    event AuctionCreated(ILeverageToken indexed leverageToken, Auction auction);

    /// @notice Event emitted when auction is taken
    event Take(ILeverageToken indexed leverageToken, address indexed taker, uint256 amountIn, uint256 amountOut);

    /// @notice Event emitted when auction ends
    event AuctionEnded(ILeverageToken indexed leverageToken);

    /// @notice Event emitted when auction duration is updated
    event AuctionDurationSet(ILeverageToken indexed leverageToken, uint256 newDuration);

    /// @notice Event emitted when initial price multiplier is updated
    event InitialPriceMultiplierSet(ILeverageToken indexed leverageToken, uint256 newMultiplier);

    /// @notice Event emitted when minimum price multiplier is updated
    event MinPriceMultiplierSet(ILeverageToken indexed leverageToken, uint256 newMultiplier);

    /// @notice Returns leverage manager
    /// @return _leverageManager Leverage manager
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice Returns auction duration
    /// @param leverageToken Leverage token to get duration for
    /// @return _auctionDuration Auction duration
    function auctionDuration(ILeverageToken leverageToken) external view returns (uint256 _auctionDuration);

    /// @notice Returns initial price multiplier
    /// @param leverageToken Leverage token to get multiplier for
    /// @return multiplier Initial price multiplier
    function initialPriceMultiplier(ILeverageToken leverageToken) external view returns (uint256 multiplier);

    /// @notice Returns minimum price multiplier
    /// @param leverageToken Leverage token to get multiplier for
    /// @return multiplier Minimum price multiplier
    function minPriceMultiplier(ILeverageToken leverageToken) external view returns (uint256 multiplier);

    /// @notice Returns leverage token rebalance status
    /// @param leverageToken Leverage token to check
    /// @return isEligibleForRebalance Whether leverage token is eligible for rebalance
    /// @return isOverCollateralized Whether leverage token is over-collateralized
    function getLeverageTokenRebalanceStatus(ILeverageToken leverageToken)
        external
        view
        returns (bool isEligibleForRebalance, bool isOverCollateralized);

    /// @notice Returns whether auction is valid
    /// @param leverageToken Leverage token to check
    /// @return isValid Whether auction is valid
    function isAuctionValid(ILeverageToken leverageToken) external view returns (bool isValid);

    /// @notice Returns current auction multiplier
    /// @param leverageToken Leverage token to get multiplier for
    /// @return multiplier Current auction multiplier
    /// @dev This module uses exponential approximation (1-x)^4 to calculate the current auction multiplier
    function getCurrentAuctionMultiplier(ILeverageToken leverageToken) external view returns (uint256 multiplier);

    /// @notice Returns amount of tokens to provide for given amount of tokens to receive
    /// @param leverageToken Leverage token to calculate for
    /// @param amountOut Amount of tokens to receive
    /// @return amountIn Amount of tokens to provide
    /// @dev If there is no valid auction in the current block, this function will still return a value based on the most recent auction
    function getAmountIn(ILeverageToken leverageToken, uint256 amountOut) external view returns (uint256 amountIn);

    /// @notice Creates new auction for leverage token that needs rebalancing
    /// @param leverageToken Leverage token to create auction for
    function createAuction(ILeverageToken leverageToken) external;

    /// @notice Ends auction for leverage token
    /// @param leverageToken Leverage token to end auction for
    function endAuction(ILeverageToken leverageToken) external;

    /// @notice Takes part in auction at current discounted price
    /// @param leverageToken Leverage token to take auction for
    /// @param amountOut Amount of tokens to receive
    function take(ILeverageToken leverageToken, uint256 amountOut) external;

    /// @notice Sets the auction duration
    /// @param leverageToken Leverage token to set duration for
    /// @param newDuration New duration in seconds
    function setAuctionDuration(ILeverageToken leverageToken, uint256 newDuration) external;

    /// @notice Sets the initial price multiplier
    /// @param leverageToken Leverage token to set multiplier for
    /// @param newMultiplier New multiplier
    function setInitialPriceMultiplier(ILeverageToken leverageToken, uint256 newMultiplier) external;

    /// @notice Sets the minimum multiplier
    /// @param leverageToken Leverage token to set multiplier for
    /// @param newMultiplier New multiplier
    function setMinPriceMultiplier(ILeverageToken leverageToken, uint256 newMultiplier) external;
}
