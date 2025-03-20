// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// Internal imports
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";
import {ISeamlessRebalanceModule} from "src/interfaces/IseamlessRebalanceModule.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract SeamlessRebalanceModule is UUPSUpgradeable, OwnableUpgradeable, ISeamlessRebalanceModule {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;

    /// @dev Struct containing all state for the SeamlessRebalanceModule contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.SeamlessRebalanceModule
    struct SeamlessRebalanceModuleStorage {
        /// @dev Address of the dutch auction module
        address dutchAuctionModule;
        /// @dev Minimum collateral ratio for a strategy, immutable
        mapping(IStrategy strategy => uint256) minCollateralRatio;
        /// @dev Maximum collateral ratio for the strategy, immutable
        mapping(IStrategy strategy => uint256) maxCollateralRatio;
    }

    function _getSeamlessRebalanceModuleStorage() internal pure returns (SeamlessRebalanceModuleStorage storage $) {
        assembly {
            $.slot := 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address initialOwner, address dutchAuctionModule) external initializer {
        __Ownable_init(initialOwner);
        _getSeamlessRebalanceModuleStorage().dutchAuctionModule = dutchAuctionModule;
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function getDutchAuctionModule() public view returns (address) {
        return _getSeamlessRebalanceModuleStorage().dutchAuctionModule;
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function getStrategyMinCollateralRatio(IStrategy strategy) public view returns (uint256) {
        return _getSeamlessRebalanceModuleStorage().minCollateralRatio[strategy];
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function getStrategyMaxCollateralRatio(IStrategy strategy) public view returns (uint256) {
        return _getSeamlessRebalanceModuleStorage().maxCollateralRatio[strategy];
    }

    /// @inheritdoc IRebalanceModule
    function isEligibleForRebalance(IStrategy strategy, StrategyState memory state, address caller)
        external
        view
        returns (bool isEligible)
    {
        if (caller != getDutchAuctionModule()) {
            return false;
        }

        uint256 minCollateralRatio = getStrategyMinCollateralRatio(strategy);
        uint256 maxCollateralRatio = getStrategyMaxCollateralRatio(strategy);

        if (state.collateralRatio >= minCollateralRatio && state.collateralRatio <= maxCollateralRatio) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IRebalanceModule
    function isStateAfterRebalanceValid(IStrategy strategy, StrategyState memory stateBefore)
        external
        view
        returns (bool isValid)
    {
        uint256 targetRatio = ILeverageManager(msg.sender).getStrategyTargetCollateralRatio(strategy);
        StrategyState memory stateAfter = ILeverageManager(msg.sender).getStrategyState(strategy);

        uint256 ratioBefore = stateBefore.collateralRatio;
        uint256 ratioAfter = stateAfter.collateralRatio;

        uint256 minRatioAfter = ratioBefore > targetRatio ? targetRatio : ratioBefore;
        uint256 maxRatioAfter = ratioBefore > targetRatio ? ratioBefore : targetRatio;

        if (ratioAfter < minRatioAfter || ratioAfter > maxRatioAfter) {
            return false;
        }

        return true;
    }

    function setStrategyCollateralRatios(IStrategy strategy, uint256 minCollateralRatio, uint256 maxCollateralRatio)
        external
        onlyOwner
    {
        if (getStrategyMinCollateralRatio(strategy) != 0 || getStrategyMaxCollateralRatio(strategy) != 0) {
            revert CollateralRatiosAlreadySet();
        }

        if (minCollateralRatio > maxCollateralRatio) {
            revert MinCollateralRatioTooHigh();
        }

        _getSeamlessRebalanceModuleStorage().minCollateralRatio[strategy] = minCollateralRatio;
        _getSeamlessRebalanceModuleStorage().maxCollateralRatio[strategy] = maxCollateralRatio;

        emit StrategyCollateralRatiosSet(strategy, minCollateralRatio, maxCollateralRatio);
    }
}
