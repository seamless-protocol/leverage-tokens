// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// Internal imports
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";
import {ISeamlessRebalanceModule} from "src/interfaces/ISeamlessRebalanceModule.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract SeamlessRebalanceModule is UUPSUpgradeable, OwnableUpgradeable, ISeamlessRebalanceModule {
    /// @dev Struct containing all state for the SeamlessRebalanceModule contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.SeamlessRebalanceModule
    struct SeamlessRebalanceModuleStorage {
        /// @dev Whether the address is authorized to rebalance
        mapping(address rebalancer => bool) isRebalancer;
        /// @dev Minimum collateral ratio for a leverage token, immutable
        mapping(ILeverageToken token => uint256) minCollateralRatio;
        /// @dev Maximum collateral ratio for a leverage token, immutable
        mapping(ILeverageToken token => uint256) maxCollateralRatio;
    }

    function _getSeamlessRebalanceModuleStorage() internal pure returns (SeamlessRebalanceModuleStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.SeamlessRebalanceModule")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x42cbc1dbee1f6a8a1b69de505df10f495d5467d974273715656d68e18b8fdd00
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function getIsRebalancer(address rebalancer) public view returns (bool) {
        return _getSeamlessRebalanceModuleStorage().isRebalancer[rebalancer];
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function getLeverageTokenMinCollateralRatio(ILeverageToken token) public view returns (uint256) {
        return _getSeamlessRebalanceModuleStorage().minCollateralRatio[token];
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function getLeverageTokenMaxCollateralRatio(ILeverageToken token) public view returns (uint256) {
        return _getSeamlessRebalanceModuleStorage().maxCollateralRatio[token];
    }

    /// @inheritdoc IRebalanceModule
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory state, address caller)
        external
        view
        returns (bool isEligible)
    {
        if (!getIsRebalancer(caller)) {
            return false;
        }

        uint256 minCollateralRatio = getLeverageTokenMinCollateralRatio(token);
        uint256 maxCollateralRatio = getLeverageTokenMaxCollateralRatio(token);

        if (state.collateralRatio >= minCollateralRatio && state.collateralRatio <= maxCollateralRatio) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IRebalanceModule
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        external
        view
        returns (bool isValid)
    {
        uint256 targetRatio = ILeverageManager(msg.sender).getLeverageTokenTargetCollateralRatio(token);
        LeverageTokenState memory stateAfter = ILeverageManager(msg.sender).getLeverageTokenState(token);

        uint256 ratioBefore = stateBefore.collateralRatio;
        uint256 ratioAfter = stateAfter.collateralRatio;

        uint256 minRatioAfter = ratioBefore > targetRatio ? targetRatio : ratioBefore;
        uint256 maxRatioAfter = ratioBefore > targetRatio ? ratioBefore : targetRatio;

        if (ratioAfter < minRatioAfter || ratioAfter > maxRatioAfter) {
            return false;
        }

        return true;
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function setIsRebalancer(address rebalancer, bool isRebalancer) external onlyOwner {
        _getSeamlessRebalanceModuleStorage().isRebalancer[rebalancer] = isRebalancer;
        emit IsRebalancerSet(rebalancer, isRebalancer);
    }

    /// @inheritdoc ISeamlessRebalanceModule
    function setLeverageTokenCollateralRatios(
        ILeverageToken token,
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) external onlyOwner {
        if (getLeverageTokenMinCollateralRatio(token) != 0 || getLeverageTokenMaxCollateralRatio(token) != 0) {
            revert CollateralRatiosAlreadySet();
        }

        if (minCollateralRatio > maxCollateralRatio) {
            revert MinCollateralRatioTooHigh();
        }

        _getSeamlessRebalanceModuleStorage().minCollateralRatio[token] = minCollateralRatio;
        _getSeamlessRebalanceModuleStorage().maxCollateralRatio[token] = maxCollateralRatio;

        emit LeverageTokenCollateralRatiosSet(token, minCollateralRatio, maxCollateralRatio);
    }
}
