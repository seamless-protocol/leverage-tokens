// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Internal imports
import {IDutchAuctionRebalanceAdapter} from "src/interfaces/IDutchAuctionRebalanceAdapter.sol";
import {IMinMaxCollateralRatioRebalanceAdapter} from "src/interfaces/IMinMaxCollateralRatioRebalanceAdapter.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
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
    /// @dev Struct containing all state for the RebalanceAdapter contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.RebalanceAdapter
    struct RebalanceAdapterStorage {
        /// @notice The authorized creator of this rebalance adapter. The authorized creator can create a
        ///         new leverage token using this adapter on the LeverageManager
        address authorizedCreator;
        /// @notice The LeverageManager contract
        ILeverageManager leverageManager;
    }

    function _getRebalanceAdapterStorage() internal pure returns (RebalanceAdapterStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.RebalanceAdapter")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0xb8978c109109e89ddaa83c20e08d73ed7aedae610788761a7cdcbd1d2ce42300
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(
        address _owner,
        address _authorizedCreator,
        ILeverageManager _leverageManager,
        uint256 _minCollateralRatio,
        uint256 _maxCollateralRatio,
        uint256 _auctionDuration,
        uint256 _initialPriceMultiplier,
        uint256 _minPriceMultiplier
    ) external initializer {
        __DutchAuctionRebalanceAdapter_init_unchained(_auctionDuration, _initialPriceMultiplier, _minPriceMultiplier);
        __MinMaxCollateralRatioRebalanceAdapter_init_unchained(_minCollateralRatio, _maxCollateralRatio);
        __Ownable_init(_owner);

        _getRebalanceAdapterStorage().authorizedCreator = _authorizedCreator;
        _getRebalanceAdapterStorage().leverageManager = _leverageManager;
    }

    /// @inheritdoc IRebalanceAdapterBase
    function postLeverageTokenCreation(address creator, address leverageToken) external {
        if (msg.sender != address(getLeverageManager())) revert Unauthorized();
        if (creator != getAuthorizedCreator()) revert Unauthorized();
        _setLeverageToken(ILeverageToken(leverageToken));
    }

    /// @inheritdoc IRebalanceAdapter
    function getAuthorizedCreator() public view returns (address) {
        return _getRebalanceAdapterStorage().authorizedCreator;
    }

    /// @inheritdoc IRebalanceAdapter
    function getLeverageManager()
        public
        view
        override(IRebalanceAdapter, DutchAuctionRebalanceAdapter, MinMaxCollateralRatioRebalanceAdapter)
        returns (ILeverageManager)
    {
        return _getRebalanceAdapterStorage().leverageManager;
    }

    /// @inheritdoc IRebalanceAdapterBase
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory state, address caller)
        public
        view
        override(IRebalanceAdapterBase, DutchAuctionRebalanceAdapter, MinMaxCollateralRatioRebalanceAdapter)
        returns (bool)
    {
        return (
            DutchAuctionRebalanceAdapter.isEligibleForRebalance(token, state, caller)
                && MinMaxCollateralRatioRebalanceAdapter.isEligibleForRebalance(token, state, caller)
        );
    }

    /// @inheritdoc IRebalanceAdapterBase
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        public
        view
        override(IRebalanceAdapterBase, DutchAuctionRebalanceAdapter, MinMaxCollateralRatioRebalanceAdapter)
        returns (bool)
    {
        return super.isStateAfterRebalanceValid(token, stateBefore);
    }
}
