// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Internal imports
import {ISeamlessRebalanceModule} from "src/interfaces/ISeamlessRebalanceModule.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {RebalanceAction, TokenTransfer, ActionType, StrategyState, Auction} from "src/types/DataTypes.sol";

contract DutchAuctionRebalancer is IDutchAuctionRebalancer, Ownable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint256 public constant PRICE_MULTIPLIER_PRECISION = 1e18;

    ///@notice Leverage manager contract
    ILeverageManager public immutable leverageManager;

    ///@notice Duration for all auctions in seconds
    mapping(IStrategy strategy => uint256) public auctionDuration;

    ///@notice Initial price multiplier in basis points
    mapping(IStrategy strategy => uint256) public initialPriceMultiplier;

    ///@notice Minimum price multiplier in basis points
    mapping(IStrategy strategy => uint256) public minPriceMultiplier;

    ///@notice Mapping of strategy to auction
    mapping(IStrategy strategy => Auction) public auctions;

    /// @notice Creates a new Dutch auction rebalancer
    /// @param owner_ Initial owner address
    /// @param leverageManager_ Address of leverage manager contract
    constructor(address owner_, ILeverageManager leverageManager_) Ownable(owner_) {
        leverageManager = leverageManager_;
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getStrategyRebalanceStatus(IStrategy strategy)
        public
        view
        returns (bool isEligibleForRebalance, bool isOverCollateralized)
    {
        StrategyState memory state = leverageManager.getStrategyState(strategy);

        ISeamlessRebalanceModule rebalanceModule =
            ISeamlessRebalanceModule(address(leverageManager.getStrategyRebalanceModule(strategy)));

        uint256 minColRatio = rebalanceModule.getStrategyMinCollateralRatio(strategy);
        uint256 maxColRatio = rebalanceModule.getStrategyMaxCollateralRatio(strategy);

        isEligibleForRebalance = state.collateralRatio < minColRatio || state.collateralRatio > maxColRatio;
        isOverCollateralized = state.collateralRatio > maxColRatio;

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

        uint256 elapsed = block.timestamp - auction.startTimestamp;
        uint256 duration = auction.endTimestamp - auction.startTimestamp;

        if (elapsed > duration) {
            return auction.minPriceMultiplier;
        }

        // Calculate progress as a fixed point number with 18 decimals
        uint256 progress = Math.mulDiv(elapsed, PRICE_MULTIPLIER_PRECISION, duration);

        // Exponential decay approximation using: e^(-3x) ≈ (1-x)^4
        uint256 base = PRICE_MULTIPLIER_PRECISION - progress; // (1-x)
        uint256 decayFactor = Math.mulDiv(base, base, PRICE_MULTIPLIER_PRECISION); // Square it: (1-x)^2
        decayFactor = Math.mulDiv(decayFactor, decayFactor, PRICE_MULTIPLIER_PRECISION); // Square again: (1-x)^4

        // Calculate final price: min + (initial - min) * decayFactor
        uint256 range = auction.initialPriceMultiplier - auction.minPriceMultiplier;
        uint256 premium = Math.mulDiv(range, decayFactor, PRICE_MULTIPLIER_PRECISION);

        return auction.minPriceMultiplier + premium;
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getAmountIn(IStrategy strategy, uint256 amountOut) public view returns (uint256) {
        bool isOverCollateralized = auctions[strategy].isOverCollateralized;
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(strategy);

        uint256 baseAmountIn = isOverCollateralized
            ? lendingAdapter.convertDebtToCollateralAsset(amountOut)
            : lendingAdapter.convertCollateralToDebtAsset(amountOut);

        return Math.mulDiv(baseAmountIn, getCurrentAuctionMultiplier(strategy), PRICE_MULTIPLIER_PRECISION);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setAuctionDuration(IStrategy strategy, uint256 newDuration) external onlyOwner {
        if (newDuration == 0) revert InvalidAuctionDuration();
        auctionDuration[strategy] = newDuration;
        emit AuctionDurationSet(strategy, newDuration);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setInitialPriceMultiplier(IStrategy strategy, uint256 newMultiplier) external onlyOwner {
        if (newMultiplier < minPriceMultiplier[strategy]) {
            revert MinPriceMultiplierTooHigh();
        }

        initialPriceMultiplier[strategy] = newMultiplier;
        emit InitialPriceMultiplierSet(strategy, newMultiplier);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setMinPriceMultiplier(IStrategy strategy, uint256 newMultiplier) external onlyOwner {
        if (newMultiplier > initialPriceMultiplier[strategy]) {
            revert MinPriceMultiplierTooHigh();
        }

        minPriceMultiplier[strategy] = newMultiplier;
        emit MinPriceMultiplierSet(strategy, newMultiplier);
    }

    /// @notice Creates a new auction
    /// @param strategy Strategy to create auction for
    function createAuction(IStrategy strategy) external {
        // End current on going auction
        endAuction(strategy);

        (bool isEligibleForRebalance, bool isOverCollateralized) = getStrategyRebalanceStatus(strategy);

        if (!isEligibleForRebalance) {
            revert StrategyNotEligibleForRebalance();
        }

        // Create new auction
        uint256 startTimestamp = block.timestamp;
        uint256 endTimestamp = startTimestamp + auctionDuration[strategy];

        console.log("isOverCollateralized", isOverCollateralized);

        Auction memory auction = Auction({
            isOverCollateralized: isOverCollateralized,
            initialPriceMultiplier: initialPriceMultiplier[strategy],
            minPriceMultiplier: minPriceMultiplier[strategy],
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
            _executeRebalanceDown(strategy, amountIn, amountOut);
        } else {
            _executeRebalanceUp(strategy, amountOut, amountIn);
        }

        emit Take(strategy, msg.sender, amountIn, amountOut);

        if (!isAuctionValid(strategy)) {
            endAuction(strategy);
        }
    }

    /// @notice Executes the rebalance down operation, meaning decreasing collateral ratio
    /// @param strategy Strategy to rebalance
    /// @param collateralAmount Amount of collateral to add
    /// @param debtAmount Amount of debt to borrow
    /// @dev This function prepares rebalance parameters, takes collateral token from sender, executes rebalance and returns debt token to sender
    function _executeRebalanceDown(IStrategy strategy, uint256 collateralAmount, uint256 debtAmount) internal {
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

    /// @notice Executes the rebalance up operation, meaning increasing collateral ratio
    /// @param strategy Strategy to rebalance
    /// @param collateralAmount Amount of collateral to remove
    /// @param debtAmount Amount of debt to repay
    /// @dev This function prepares rebalance parameters, takes debt token from sender, executes rebalance and returns collateral token to sender
    function _executeRebalanceUp(IStrategy strategy, uint256 collateralAmount, uint256 debtAmount) internal {
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
