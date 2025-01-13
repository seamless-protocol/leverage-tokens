// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {ILendingAdapter} from "../../../interfaces/ILendingAdapter.sol";
import {IMorphoLendingAdapter} from "../../../interfaces/IMorphoLendingAdapter.sol";
import {Id, IMorpho, MarketParams} from "../../../vendor/morpho/IMorpho.sol";

contract MorphoLendingAdapter is IMorphoLendingAdapter, Initializable {

    /// @inheritdoc IMorphoLendingAdapter
    IMorpho public morpho;

    /// @inheritdoc IMorphoLendingAdapter
    Id public marketId;

    /// @notice Initialize the lending adapter
    /// @dev An initializer is used instead of a constructor as it is intended to be used within a beacon proxy setup
    /// @param _morpho The Morpho lending pool
    /// @param _marketId The market ID
    function initialize(IMorpho _morpho, Id _marketId) external initializer {
        morpho = _morpho;
        marketId = _marketId;
    }

    /// @inheritdoc ILendingAdapter
    function getStrategyCollateral(address /* strategy */) external view returns (uint256 collateral) {
        // TODO: Implement this
        return block.timestamp;
    }

    /// @inheritdoc ILendingAdapter
    function getStrategyEquityInDebtAsset(address /* strategy */) external view returns (uint256 equity) {
        // TODO: Implement this
        return block.timestamp;
    }

    /// @inheritdoc ILendingAdapter
    function convertCollateralToDebtAsset(address /* strategy */, uint256 /* collateral */) external view returns (uint256 debt) {
        // TODO: Implement this
        return block.timestamp;
    }

    /// @inheritdoc ILendingAdapter
    function addCollateral(address /* strategy */, uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory marketParams = _morpho.idToMarketParams(marketId);

        // Transfer the collateral from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(marketParams.collateralToken), msg.sender, address(this), amount);

        // Supply the collateral to the Morpho market
        IERC20(marketParams.collateralToken).approve(address(_morpho), amount);
        _morpho.supplyCollateral(marketParams, amount, address(this), hex"");
    }

    /// @inheritdoc ILendingAdapter
    function removeCollateral(address /* strategy */, uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory marketParams = _morpho.idToMarketParams(marketId);

        // Withdraw the collateral from the Morpho market and send it to msg.sender
        _morpho.withdrawCollateral(marketParams, amount, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function borrow(address /* strategy */, uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory marketParams = _morpho.idToMarketParams(marketId);

        // Borrow the debt asset from the Morpho market and send it to the caller
        _morpho.borrow(marketParams, amount, 0, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function repay(address /* strategy */, uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory marketParams = _morpho.idToMarketParams(marketId);

        // Transfer the debt asset from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(marketParams.loanToken), msg.sender, address(this), amount);

        // Repay the debt asset to the Morpho market
        IERC20(marketParams.loanToken).approve(address(_morpho), amount);
        _morpho.repay(marketParams, amount, 0, address(this), hex"");
    }
}
