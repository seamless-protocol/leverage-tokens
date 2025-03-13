// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IDutchAuctionRebalancer} from "./interfaces/IDutchAuctionRebalancer.sol";
import {ILeverageManager} from "./interfaces/ILeverageManager.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {ILendingAdapter} from "./interfaces/ILendingAdapter.sol";
import {RebalanceAction, TokenTransfer, ActionType, StrategyState, CollateralRatios} from "./types/DataTypes.sol";

contract DutchAuctionRebalancer is IDutchAuctionRebalancer, Ownable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint256 public constant BPS_DENOMINATOR = 100_00;

    ///@notice Leverage manager contract
    ILeverageManager public immutable leverageManager;

    ///@notice Duration for all auctions in seconds
    uint256 public auctionDuration;

    ///@notice Initial price premium in basis points
    uint256 public initialPricePremiumBps;

    ///@notice Mapping of strategy to auction
    mapping(IStrategy strategy => Auction) public auctions;

    /// @notice Creates a new Dutch auction rebalancer
    /// @param owner_ Initial owner address
    /// @param leverageManager_ Address of leverage manager contract
    /// @param auctionDuration_ Fixed duration for all auctions in seconds
    /// @param initialPricePremiumBps_ Initial price premium in basis points
    constructor(
        address owner_,
        ILeverageManager leverageManager_,
        uint256 auctionDuration_,
        uint256 initialPricePremiumBps_
    ) Ownable(owner_) {
        if (auctionDuration_ == 0) revert InvalidAuctionDuration();
        if (initialPricePremiumBps_ > BPS_DENOMINATOR) revert InvalidPricePremium();

        leverageManager = leverageManager_;
        auctionDuration = auctionDuration_;
        initialPricePremiumBps = initialPricePremiumBps_;
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getStrategyRebalanceStatus(IStrategy strategy)
        public
        view
        returns (bool isEligibleForRebalance, bool isOverCollateralized)
    {
        StrategyState memory state = leverageManager.getStrategyState(strategy);
        CollateralRatios memory ratios = leverageManager.getStrategyCollateralRatios(strategy);

        isEligibleForRebalance =
            state.collateralRatio < ratios.minCollateralRatio || state.collateralRatio > ratios.maxCollateralRatio;
        isOverCollateralized = state.collateralRatio > ratios.maxCollateralRatio;

        return (isEligibleForRebalance, isOverCollateralized);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function isAuctionValid(IStrategy strategy) public view returns (bool isValid) {
        (bool isEligibleForRebalance, bool isOverCollateralized) = getStrategyRebalanceStatus(strategy);

        if (!isEligibleForRebalance) {
            return false;
        }

        if (isOverCollateralized != auctions[strategy].isOverCollateralized) {
            return false;
        }

        if (block.timestamp > auctions[strategy].endTimestamp) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getCurrentAuctionMultiplier(IStrategy strategy) public view returns (uint256) {
        Auction memory auction = auctions[strategy];

        uint256 elapsedTime = block.timestamp - auction.startTimestamp;
        uint256 duration = auction.endTimestamp - auction.startTimestamp;

        // Calculate current price using linear decay
        return Math.mulDiv(auction.initialPriceMultiplier, duration - elapsedTime, duration);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getAmountIn(IStrategy strategy, uint256 amountOut) public view returns (uint256) {
        bool isOverCollateralized = auctions[strategy].isOverCollateralized;
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(strategy);

        uint256 baseAmountIn = isOverCollateralized
            ? lendingAdapter.convertDebtToCollateralAsset(amountOut)
            : lendingAdapter.convertCollateralToDebtAsset(amountOut);

        return Math.mulDiv(baseAmountIn, getCurrentAuctionMultiplier(strategy), BPS_DENOMINATOR);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setAuctionDuration(uint256 newDuration) external onlyOwner {
        if (newDuration == 0) revert InvalidAuctionDuration();
        auctionDuration = newDuration;
        emit AuctionDurationSet(newDuration);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setInitialPricePremium(uint256 newPremiumBps) external onlyOwner {
        if (newPremiumBps > BPS_DENOMINATOR) revert InvalidPricePremium();
        initialPricePremiumBps = newPremiumBps;
        emit InitialPricePremiumSet(newPremiumBps);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function createAuction(IStrategy strategy) external {
        // End current on going auction
        endAuction(strategy);

        (bool isEligibleForRebalance, bool isOverCollateralized) = getStrategyRebalanceStatus(strategy);

        if (!isEligibleForRebalance) {
            revert StrategyNotEligibleForRebalance();
        }

        // Create new auction
        uint256 startTimestamp = block.timestamp;
        uint256 endTimestamp = startTimestamp + auctionDuration;

        Auction memory auction = Auction({
            isOverCollateralized: isOverCollateralized,
            initialPriceMultiplier: BPS_DENOMINATOR + initialPricePremiumBps,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        });

        auctions[strategy] = auction;
        emit AuctionCreated(strategy, auction);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function endAuction(IStrategy strategy) public {
        if (isAuctionValid(strategy)) {
            revert AuctionStillValid();
        }

        delete auctions[strategy];
        emit AuctionEnded(strategy);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function take(IStrategy strategy, uint256 amountOut) external {
        if (!isAuctionValid(strategy)) {
            revert AuctionNotValid();
        }

        uint256 amountIn = getAmountIn(strategy, amountOut);

        if (auctions[strategy].isOverCollateralized) {
            _executeRebalanceUp(strategy, amountIn, amountOut);
        } else {
            _executeRebalanceDown(strategy, amountIn, amountOut);
        }

        emit Take(strategy, msg.sender, amountIn, amountOut);

        if (!isAuctionValid(strategy)) {
            endAuction(strategy);
        }
    }

    /// @notice Executes the rebalance operation
    /// @param strategy Strategy to rebalance
    /// @param collateralAmount Amount of collateral to add
    /// @param debtAmount Amount of debt to borrow
    /// @dev This function prepares rebalance parameters, takes collateral token from sender, executes rebalance and returns debt token to sender
    function _executeRebalanceUp(IStrategy strategy, uint256 collateralAmount, uint256 debtAmount) internal {
        // Get token addresses
        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(strategy);
        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(strategy);

        // Prepare rebalance actions
        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] =
            RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: collateralAmount});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: debtAmount});

        // Prepare token transfers
        TokenTransfer[] memory tokensIn = new TokenTransfer[](1);
        tokensIn[0] = TokenTransfer({token: address(collateralAsset), amount: collateralAmount});

        TokenTransfer[] memory tokensOut = new TokenTransfer[](1);
        tokensOut[0] = TokenTransfer({token: address(debtAsset), amount: debtAmount});

        collateralAsset.safeTransferFrom(msg.sender, address(this), collateralAmount);
        collateralAsset.approve(address(leverageManager), collateralAmount);
        leverageManager.rebalance(actions, tokensIn, tokensOut);

        debtAsset.safeTransfer(msg.sender, debtAmount);
    }

    /// @notice Executes the rebalance operation
    /// @param strategy Strategy to rebalance
    /// @param collateralAmount Amount of collateral to remove
    /// @param debtAmount Amount of debt to repay
    /// @dev This function prepares rebalance parameters, takes debt token from sender, executes rebalance and returns collateral token to sender
    function _executeRebalanceDown(IStrategy strategy, uint256 collateralAmount, uint256 debtAmount) internal {
        // Get token addresses
        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(strategy);
        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(strategy);

        // Prepare rebalance actions
        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.Repay, amount: debtAmount});
        actions[1] =
            RebalanceAction({strategy: strategy, actionType: ActionType.RemoveCollateral, amount: collateralAmount});

        // Prepare token transfers
        TokenTransfer[] memory tokensIn = new TokenTransfer[](1);
        tokensIn[0] = TokenTransfer({token: address(debtAsset), amount: debtAmount});

        TokenTransfer[] memory tokensOut = new TokenTransfer[](1);
        tokensOut[0] = TokenTransfer({token: address(collateralAsset), amount: collateralAmount});

        debtAsset.safeTransferFrom(msg.sender, address(this), debtAmount);
        debtAsset.approve(address(leverageManager), debtAmount);
        leverageManager.rebalance(actions, tokensIn, tokensOut);

        collateralAsset.safeTransfer(msg.sender, collateralAmount);
    }
}
