// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILeverageToken} from "./ILeverageToken.sol";
import {ILeverageManager} from "./ILeverageManager.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {Auction} from "src/types/DataTypes.sol";

interface IDutchAuctionRebalanceAdapter {
    /// @notice Error thrown when leverage token is already set
    error LeverageTokenAlreadySet();

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

    /// @notice Event emitted when Dutch auction rebalancer is initialized
    event DutchAuctionRebalanceAdapterInitialized(
        uint256 auctionDuration, uint256 initialPriceMultiplier, uint256 minPriceMultiplier
    );

    /// @notice Event emitted when leverage token is set
    event LeverageTokenSet(ILeverageToken leverageToken);

    /// @notice Event emitted when new auction is created
    event AuctionCreated(Auction auction);

    /// @notice Event emitted when auction is taken
    event Take(address indexed taker, uint256 amountIn, uint256 amountOut);

    /// @notice Event emitted when auction ends
    event AuctionEnded();

    /// @notice Event emitted when auction duration is updated
    event AuctionDurationSet(uint256 newDuration);

    /// @notice Event emitted when initial price multiplier is updated
    event InitialPriceMultiplierSet(uint256 newMultiplier);

    /// @notice Event emitted when minimum price multiplier is updated
    event MinPriceMultiplierSet(uint256 newMultiplier);

    /// @notice Returns leverage manager
    /// @return leverageManager Leverage manager
    function getLeverageManager() external view returns (ILeverageManager leverageManager);

    /// @notice Returns leverage token
    /// @return leverageToken Leverage token
    function getLeverageToken() external view returns (ILeverageToken leverageToken);

    /// @notice Returns auction
    /// @return auction Auction
    function getAuction() external view returns (Auction memory auction);

    /// @notice Returns auction duration
    /// @return auctionDuration Auction duration
    function getAuctionDuration() external view returns (uint256 auctionDuration);

    /// @notice Returns initial price multiplier
    /// @return multiplier Initial price multiplier
    function getInitialPriceMultiplier() external view returns (uint256 multiplier);

    /// @notice Returns minimum price multiplier
    /// @return multiplier Minimum price multiplier
    function getMinPriceMultiplier() external view returns (uint256 multiplier);

    /// @notice Returns leverage token rebalance status
    /// @return isEligibleForRebalance Whether leverage token is eligible for rebalance
    /// @return isOverCollateralized Whether leverage token is over-collateralized
    function getLeverageTokenRebalanceStatus()
        external
        view
        returns (bool isEligibleForRebalance, bool isOverCollateralized);

    /// @notice Returns current auction multiplier
    /// @return multiplier Current auction multiplier
    /// @dev This module uses exponential approximation (1-x)^4 to calculate the current auction multiplier
    function getCurrentAuctionMultiplier() external view returns (uint256 multiplier);

    /// @notice Returns true if the leverage token is eligible for rebalance
    /// @param token The leverage token
    /// @param state The state of the leverage token
    /// @param caller The caller of the function
    /// @return isEligible True if the leverage token is eligible for rebalance, false otherwise
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory state, address caller)
        external
        view
        returns (bool isEligible);

    /// @notice Returns true if the leverage token state after rebalance is valid
    /// @param token The leverage token
    /// @param stateBefore The state of the leverage token before rebalance
    /// @return isValid True if the leverage token state after rebalance is valid, false otherwise
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        external
        view
        returns (bool isValid);

    /// @notice Returns whether auction is valid
    /// @return isValid Whether auction is valid
    function isAuctionValid() external view returns (bool isValid);

    /// @notice Returns amount of tokens to provide for given amount of tokens to receive
    /// @param amountOut Amount of tokens to receive
    /// @return amountIn Amount of tokens to provide
    /// @dev If there is no valid auction in the current block, this function will still return a value based on the most recent auction
    function getAmountIn(uint256 amountOut) external view returns (uint256 amountIn);

    /// @notice Creates new auction for leverage token that needs rebalancing
    function createAuction() external;

    /// @notice Ends auction for leverage token
    function endAuction() external;

    /// @notice Takes part in auction at current discounted price
    /// @param amountOut Amount of tokens to receive
    function take(uint256 amountOut) external;
}
