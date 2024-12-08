// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FeeManagerStorage as Storage} from "./storage/FeeManagerStorage.sol";
import {IFeeManager} from "./interfaces/IFeeManager.sol";

contract FeeManager is IFeeManager, AccessControlUpgradeable {
    // Max fee that can be ste, 100_00 is 100%
    uint256 public constant MAX_FEE = 100_00;
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    function __FeeManager_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IFeeManager
    function getTreasury() public view returns (address treasury) {
        return Storage.layout().treasury;
    }

    /// @inheritdoc IFeeManager
    function getStrategyFeeConfig(address strategy) external view returns (Storage.StrategyFeeConfig memory config) {
        return Storage.layout().strategyFeeConfig[strategy];
    }

    /// @inheritdoc IFeeManager
    function setTreasury(address treasury) external onlyRole(FEE_MANAGER_ROLE) {
        Storage.layout().treasury = treasury;
        emit TreasurySet(treasury);
    }

    /// @inheritdoc IFeeManager
    function setStrategyFeeConfig(address strategy, Storage.StrategyFeeConfig memory config)
        external
        onlyRole(FEE_MANAGER_ROLE)
    {
        // Check if fees are not higher than 100%
        if (config.depositFee > MAX_FEE || config.withdrawFee > MAX_FEE || config.compoundFee > MAX_FEE) {
            revert FeeTooHigh();
        }

        Storage.layout().strategyFeeConfig[strategy] = config;
        emit StrategyFeeConfigSet(strategy, config);
    }

    // Calculates and charges fee based on action type. Fee is sent to treasury
    function _chargeStrategyFee(address strategy, uint256 amount, IFeeManager.Action action)
        internal
        returns (uint256 feeAmount)
    {
        // Calculate deposit fee (always round down up) and send it to treasury
        // This contract should be inherited by LeverageManager so we charge fees from this address
        feeAmount = Math.mulDiv(amount, _getFeeBasedOnAction(strategy, action), MAX_FEE, Math.Rounding.Ceil);

        // Emit event and explicit return statement
        emit FeeCharged(strategy, action, amount, feeAmount);
        return feeAmount;
    }

    // Returns fee percentage based on action type on strategy
    function _getFeeBasedOnAction(address strategy, IFeeManager.Action action) private view returns (uint8 fee) {
        // Get fee configuration for strategy in storage not memory to avoid copying entire struct to memory, only reference/storage slot
        Storage.StrategyFeeConfig storage feeConfig = Storage.layout().strategyFeeConfig[strategy];

        if (action == IFeeManager.Action.Deposit) {
            return feeConfig.depositFee;
        } else if (action == IFeeManager.Action.Withdraw) {
            return feeConfig.withdrawFee;
        } else if (action == IFeeManager.Action.Compound) {
            return feeConfig.compoundFee;
        }
    }
}
