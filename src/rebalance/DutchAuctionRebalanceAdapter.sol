// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {IDutchAuctionRebalanceAdapter} from "src/interfaces/IDutchAuctionRebalanceAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {RebalanceAction, TokenTransfer, ActionType, LeverageTokenState, Auction} from "src/types/DataTypes.sol";

abstract contract DutchAuctionRebalanceAdapter is IDutchAuctionRebalanceAdapter, Initializable {
    uint256 public constant PRICE_MULTIPLIER_PRECISION = 1e18;

    /// @dev Struct containing all state for the DutchAuctionRebalanceAdapter contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.DutchAuctionRebalanceAdapter
    struct DutchAuctionRebalanceAdapterStorage {
        /// @notice Leverage manager contract
        ILeverageManager leverageManager;
        /// @notice Leverage token that this dutch auction rebalancer is for
        ILeverageToken leverageToken;
        /// @notice Currently active auction
        Auction auction;
        /// @notice Duration for all auctions in seconds
        uint256 auctionDuration;
        /// @notice Initial price multiplier relative to oracle price
        uint256 initialPriceMultiplier;
        /// @notice Minimum price multiplier relative to oracle price
        uint256 minPriceMultiplier;
    }

    function _getDutchAuctionRebalanceAdapterStorage()
        internal
        pure
        returns (DutchAuctionRebalanceAdapterStorage storage $)
    {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.DutchAuctionRebalanceAdapter")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x5a17ed03c9224a83c249c4c9f6b3c3ee77f4a278901f975cbdbdcd094252ab00
        }
    }

    function __DutchAuctionRebalanceAdapter_init_unchained(
        ILeverageManager _leverageManager,
        ILeverageToken _leverageToken,
        uint256 _auctionDuration,
        uint256 _initialPriceMultiplier,
        uint256 _minPriceMultiplier
    ) internal onlyInitializing {
        if (_minPriceMultiplier > _initialPriceMultiplier) {
            revert MinPriceMultiplierTooHigh();
        }

        if (_auctionDuration == 0) {
            revert InvalidAuctionDuration();
        }

        DutchAuctionRebalanceAdapterStorage storage $ = _getDutchAuctionRebalanceAdapterStorage();
        $.leverageManager = _leverageManager;
        $.leverageToken = _leverageToken;
        $.auctionDuration = _auctionDuration;
        $.initialPriceMultiplier = _initialPriceMultiplier;
        $.minPriceMultiplier = _minPriceMultiplier;

        emit DutchAuctionRebalanceAdapterInitialized(
            _leverageManager, _leverageToken, _auctionDuration, _initialPriceMultiplier, _minPriceMultiplier
        );
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getLeverageManager() public view returns (ILeverageManager) {
        return _getDutchAuctionRebalanceAdapterStorage().leverageManager;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getLeverageToken() public view returns (ILeverageToken) {
        return _getDutchAuctionRebalanceAdapterStorage().leverageToken;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getAuction() public view returns (Auction memory auction) {
        return _getDutchAuctionRebalanceAdapterStorage().auction;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getAuctionDuration() public view returns (uint256) {
        return _getDutchAuctionRebalanceAdapterStorage().auctionDuration;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getInitialPriceMultiplier() public view returns (uint256) {
        return _getDutchAuctionRebalanceAdapterStorage().initialPriceMultiplier;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getMinPriceMultiplier() public view returns (uint256) {
        return _getDutchAuctionRebalanceAdapterStorage().minPriceMultiplier;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getLeverageTokenRebalanceStatus() public view returns (bool isEligible, bool isOverCollateralized) {
        ILeverageToken token = getLeverageToken();
        ILeverageManager leverageManager = getLeverageManager();

        uint256 targetRatio = leverageManager.getLeverageTokenTargetCollateralRatio(token);
        LeverageTokenState memory state = leverageManager.getLeverageTokenState(token);

        isEligible = isEligibleForRebalance(token, state, address(this));
        isOverCollateralized = state.collateralRatio > targetRatio;

        return (isEligible, isOverCollateralized);
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function isAuctionValid() public view returns (bool isValid) {
        (bool isEligible, bool isOverCollateralized) = getLeverageTokenRebalanceStatus();

        if (!isEligible) {
            return false;
        }

        Auction memory auction = getAuction();

        if (isOverCollateralized != auction.isOverCollateralized) {
            return false;
        }

        // slither-disable-next-line timestamp
        if (block.timestamp > auction.endTimestamp) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getCurrentAuctionMultiplier() public view returns (uint256) {
        Auction memory auction = getAuction();

        uint256 elapsed = block.timestamp - auction.startTimestamp;
        uint256 duration = auction.endTimestamp - auction.startTimestamp;

        uint256 minPriceMultiplier = getMinPriceMultiplier();
        uint256 initialPriceMultiplier = getInitialPriceMultiplier();

        // slither-disable-next-line timestamp
        if (elapsed > duration) {
            return minPriceMultiplier;
        }

        // Calculate progress as a fixed point number with 18 decimals
        uint256 progress = Math.mulDiv(elapsed, PRICE_MULTIPLIER_PRECISION, duration);

        // Exponential decay approximation using: e^(-3x) ≈ (1-x)^4
        uint256 base = PRICE_MULTIPLIER_PRECISION - progress; // (1-x)
        uint256 decayFactor = Math.mulDiv(base, base, PRICE_MULTIPLIER_PRECISION); // Square it: (1-x)^2
        decayFactor = Math.mulDiv(decayFactor, decayFactor, PRICE_MULTIPLIER_PRECISION); // Square again: (1-x)^4

        // Calculate final price: min + (initial - min) * decayFactor
        uint256 range = initialPriceMultiplier - minPriceMultiplier;
        uint256 premium = Math.mulDiv(range, decayFactor, PRICE_MULTIPLIER_PRECISION);

        return minPriceMultiplier + premium;
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function getAmountIn(uint256 amountOut) public view returns (uint256) {
        bool isOverCollateralized = getAuction().isOverCollateralized;
        ILendingAdapter lendingAdapter = getLeverageManager().getLeverageTokenLendingAdapter(getLeverageToken());

        uint256 baseAmountIn = isOverCollateralized
            ? lendingAdapter.convertDebtToCollateralAsset(amountOut)
            : lendingAdapter.convertCollateralToDebtAsset(amountOut);

        return Math.mulDiv(baseAmountIn, getCurrentAuctionMultiplier(), PRICE_MULTIPLIER_PRECISION);
    }

    function createAuction() external {
        // End current on going auction
        endAuction();

        (bool isEligible, bool isOverCollateralized) = getLeverageTokenRebalanceStatus();

        if (!isEligible) {
            revert LeverageTokenNotEligibleForRebalance();
        }

        // Create new auction
        uint256 startTimestamp = block.timestamp;
        uint256 endTimestamp = startTimestamp + getAuctionDuration();

        Auction memory auction = Auction({
            isOverCollateralized: isOverCollateralized,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        });

        _getDutchAuctionRebalanceAdapterStorage().auction = auction;
        emit AuctionCreated(auction);
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function endAuction() public {
        if (isAuctionValid()) {
            revert AuctionStillValid();
        }

        delete _getDutchAuctionRebalanceAdapterStorage().auction;
        emit AuctionEnded();
    }

    /// @inheritdoc IDutchAuctionRebalanceAdapter
    function take(uint256 amountOut) external {
        if (!isAuctionValid()) {
            revert AuctionNotValid();
        }

        uint256 amountIn = getAmountIn(amountOut);

        if (getAuction().isOverCollateralized) {
            _executeRebalanceDown(amountIn, amountOut);
        } else {
            _executeRebalanceUp(amountOut, amountIn);
        }

        emit Take(msg.sender, amountIn, amountOut);

        if (!isAuctionValid()) {
            endAuction();
        }
    }

    /// @notice Executes the rebalance down operation, meaning decreasing collateral ratio
    /// @param collateralAmount Amount of collateral to add
    /// @param debtAmount Amount of debt to borrow
    /// @dev This function prepares rebalance parameters, takes collateral token from sender, executes rebalance and returns debt token to sender
    function _executeRebalanceDown(uint256 collateralAmount, uint256 debtAmount) internal {
        ILeverageToken token = getLeverageToken();
        ILeverageManager leverageManager = getLeverageManager();

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

        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), collateralAmount);

        // slither-disable-next-line reentrancy-events
        SafeERC20.forceApprove(collateralAsset, address(leverageManager), collateralAmount);

        // slither-disable-next-line reentrancy-events
        leverageManager.rebalance(actions, tokensIn, tokensOut);

        SafeERC20.safeTransfer(debtAsset, msg.sender, debtAmount);
    }

    /// @notice Executes the rebalance up operation, meaning increasing collateral ratio
    /// @param collateralAmount Amount of collateral to remove
    /// @param debtAmount Amount of debt to repay
    /// @dev This function prepares rebalance parameters, takes debt token from sender, executes rebalance and returns collateral token to sender
    function _executeRebalanceUp(uint256 collateralAmount, uint256 debtAmount) internal {
        ILeverageToken token = getLeverageToken();
        ILeverageManager leverageManager = getLeverageManager();

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

        SafeERC20.safeTransferFrom(debtAsset, msg.sender, address(this), debtAmount);

        // slither-disable-next-line reentrancy-events
        SafeERC20.forceApprove(debtAsset, address(leverageManager), debtAmount);

        // slither-disable-next-line reentrancy-events
        leverageManager.rebalance(actions, tokensIn, tokensOut);

        SafeERC20.safeTransfer(collateralAsset, msg.sender, collateralAmount);
    }

    function isEligibleForRebalance(ILeverageToken, LeverageTokenState memory, address caller)
        public
        view
        virtual
        returns (bool)
    {
        return caller == address(this);
    }

    function isStateAfterRebalanceValid(ILeverageToken, LeverageTokenState memory) public view virtual returns (bool);
}
