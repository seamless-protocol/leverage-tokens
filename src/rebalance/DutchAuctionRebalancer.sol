// SPDX-License-Identifier: MIT
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
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {RebalanceAction, TokenTransfer, ActionType, LeverageTokenState, Auction} from "src/types/DataTypes.sol";

contract DutchAuctionRebalancer is IDutchAuctionRebalancer, Ownable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint256 public constant PRICE_MULTIPLIER_PRECISION = 1e18;

    ///@notice Leverage manager contract
    ILeverageManager public immutable leverageManager;

    ///@notice Duration for all auctions in seconds
    mapping(ILeverageToken token => uint256) public auctionDuration;

    ///@notice Initial price multiplier in basis points
    mapping(ILeverageToken token => uint256) public initialPriceMultiplier;

    ///@notice Minimum price multiplier in basis points
    mapping(ILeverageToken token => uint256) public minPriceMultiplier;

    ///@notice Mapping of leverage token to auction
    mapping(ILeverageToken token => Auction) public auctions;

    /// @notice Creates a new Dutch auction rebalancer
    /// @param owner_ Initial owner address
    /// @param leverageManager_ Address of leverage manager contract
    constructor(address owner_, ILeverageManager leverageManager_) Ownable(owner_) {
        leverageManager = leverageManager_;
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getLeverageTokenRebalanceStatus(ILeverageToken token)
        public
        view
        returns (bool isEligibleForRebalance, bool isOverCollateralized)
    {
        LeverageTokenState memory state = leverageManager.getLeverageTokenState(token);

        ISeamlessRebalanceModule rebalanceModule =
            ISeamlessRebalanceModule(address(leverageManager.getLeverageTokenRebalanceModule(token)));

        uint256 minColRatio = rebalanceModule.getLeverageTokenMinCollateralRatio(token);
        uint256 maxColRatio = rebalanceModule.getLeverageTokenMaxCollateralRatio(token);

        isEligibleForRebalance = state.collateralRatio < minColRatio || state.collateralRatio > maxColRatio;
        isOverCollateralized = state.collateralRatio > maxColRatio;

        return (isEligibleForRebalance, isOverCollateralized);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function isAuctionValid(ILeverageToken token) public view returns (bool isValid) {
        (bool isEligibleForRebalance, bool isOverCollateralized) = getLeverageTokenRebalanceStatus(token);

        if (!isEligibleForRebalance) {
            return false;
        }

        if (isOverCollateralized != auctions[token].isOverCollateralized) {
            return false;
        }

        if (block.timestamp > auctions[token].endTimestamp) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function getCurrentAuctionMultiplier(ILeverageToken token) public view returns (uint256) {
        Auction memory auction = auctions[token];

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
    function getAmountIn(ILeverageToken token, uint256 amountOut) public view returns (uint256) {
        bool isOverCollateralized = auctions[token].isOverCollateralized;
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(token);

        uint256 baseAmountIn = isOverCollateralized
            ? lendingAdapter.convertDebtToCollateralAsset(amountOut)
            : lendingAdapter.convertCollateralToDebtAsset(amountOut);

        return Math.mulDiv(baseAmountIn, getCurrentAuctionMultiplier(token), PRICE_MULTIPLIER_PRECISION);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setAuctionDuration(ILeverageToken token, uint256 newDuration) external onlyOwner {
        if (newDuration == 0) revert InvalidAuctionDuration();
        auctionDuration[token] = newDuration;
        emit AuctionDurationSet(token, newDuration);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setInitialPriceMultiplier(ILeverageToken token, uint256 newMultiplier) external onlyOwner {
        if (newMultiplier < minPriceMultiplier[token]) {
            revert MinPriceMultiplierTooHigh();
        }

        initialPriceMultiplier[token] = newMultiplier;
        emit InitialPriceMultiplierSet(token, newMultiplier);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function setMinPriceMultiplier(ILeverageToken token, uint256 newMultiplier) external onlyOwner {
        if (newMultiplier > initialPriceMultiplier[token]) {
            revert MinPriceMultiplierTooHigh();
        }

        minPriceMultiplier[token] = newMultiplier;
        emit MinPriceMultiplierSet(token, newMultiplier);
    }

    /// @notice Creates a new auction
    /// @param token Leverage token to create auction for
    function createAuction(ILeverageToken token) external {
        // End current on going auction
        endAuction(token);

        (bool isEligibleForRebalance, bool isOverCollateralized) = getLeverageTokenRebalanceStatus(token);

        if (!isEligibleForRebalance) {
            revert LeverageTokenNotEligibleForRebalance();
        }

        // Create new auction
        uint256 startTimestamp = block.timestamp;
        uint256 endTimestamp = startTimestamp + auctionDuration[token];

        Auction memory auction = Auction({
            isOverCollateralized: isOverCollateralized,
            initialPriceMultiplier: initialPriceMultiplier[token],
            minPriceMultiplier: minPriceMultiplier[token],
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        });

        auctions[token] = auction;
        emit AuctionCreated(token, auction);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function endAuction(ILeverageToken token) public {
        if (isAuctionValid(token)) {
            revert AuctionStillValid();
        }

        delete auctions[token];
        emit AuctionEnded(token);
    }

    /// @inheritdoc IDutchAuctionRebalancer
    function take(ILeverageToken token, uint256 amountOut) external {
        if (!isAuctionValid(token)) {
            revert AuctionNotValid();
        }

        uint256 amountIn = getAmountIn(token, amountOut);

        if (auctions[token].isOverCollateralized) {
            _executeRebalanceDown(token, amountIn, amountOut);
        } else {
            _executeRebalanceUp(token, amountOut, amountIn);
        }

        emit Take(token, msg.sender, amountIn, amountOut);

        if (!isAuctionValid(token)) {
            endAuction(token);
        }
    }

    /// @notice Executes the rebalance down operation, meaning decreasing collateral ratio
    /// @param token Leverage token to rebalance
    /// @param collateralAmount Amount of collateral to add
    /// @param debtAmount Amount of debt to borrow
    /// @dev This function prepares rebalance parameters, takes collateral token from sender, executes rebalance and returns debt token to sender
    function _executeRebalanceDown(ILeverageToken token, uint256 collateralAmount, uint256 debtAmount) internal {
        // Get token addresses
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(token);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(token);

        // Prepare rebalance actions
        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] =
            RebalanceAction({leverageToken: token, actionType: ActionType.AddCollateral, amount: collateralAmount});
        actions[1] = RebalanceAction({leverageToken: token, actionType: ActionType.Borrow, amount: debtAmount});

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
    /// @param token Leverage token to rebalance
    /// @param collateralAmount Amount of collateral to remove
    /// @param debtAmount Amount of debt to repay
    /// @dev This function prepares rebalance parameters, takes debt token from sender, executes rebalance and returns collateral token to sender
    function _executeRebalanceUp(ILeverageToken token, uint256 collateralAmount, uint256 debtAmount) internal {
        // Get token addresses
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(token);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(token);

        // Prepare rebalance actions
        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({leverageToken: token, actionType: ActionType.Repay, amount: debtAmount});
        actions[1] =
            RebalanceAction({leverageToken: token, actionType: ActionType.RemoveCollateral, amount: collateralAmount});

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
