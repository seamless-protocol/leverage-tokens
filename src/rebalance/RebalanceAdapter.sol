// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {DutchAuctionRebalanceAdapter} from "src/rebalance/DutchAuctionRebalanceAdapter.sol";
import {MinMaxCollateralRatioRebalanceAdapter} from "src/rebalance/MinMaxCollateralRatioRebalanceAdapter.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract RebalanceAdapter is
    IRebalanceAdapter,
    UUPSUpgradeable,
    OwnableUpgradeable,
    MinMaxCollateralRatioRebalanceAdapter,
    DutchAuctionRebalanceAdapter
{
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(ILeverageToken leverageToken, bytes calldata initData) external initializer {
        (
            address _owner,
            ILeverageManager leverageManager,
            uint256 minCollateralRatio,
            uint256 maxCollateralRatio,
            uint256 auctionDuration,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier
        ) = abi.decode(initData, (address, ILeverageManager, uint256, uint256, uint256, uint256, uint256));

        __Ownable_init(_owner);
        __MinMaxCollateralRatioRebalanceAdapter_init_unchained(minCollateralRatio, maxCollateralRatio);
        __DutchAuctionRebalanceAdapter_init_unchained(
            leverageManager, leverageToken, auctionDuration, initialPriceMultiplier, minPriceMultiplier
        );
    }

    /// @inheritdoc IRebalanceAdapter
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory state, address caller)
        public
        view
        override(IRebalanceAdapter, DutchAuctionRebalanceAdapter, MinMaxCollateralRatioRebalanceAdapter)
        returns (bool)
    {
        return (
            DutchAuctionRebalanceAdapter.isEligibleForRebalance(token, state, caller)
                && MinMaxCollateralRatioRebalanceAdapter.isEligibleForRebalance(token, state, caller)
        );
    }

    /// @inheritdoc IRebalanceAdapter
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        public
        view
        override(IRebalanceAdapter, DutchAuctionRebalanceAdapter, MinMaxCollateralRatioRebalanceAdapter)
        returns (bool)
    {
        return super.isStateAfterRebalanceValid(token, stateBefore);
    }
}
