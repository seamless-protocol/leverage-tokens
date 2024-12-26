// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {FeeManagerStorage as Storage} from "./storage/FeeManagerStorage.sol";
import {IFeeManager} from "./interfaces/IFeeManager.sol";

contract FeeManager is IFeeManager, Initializable, AccessControlUpgradeable {
    // Max fee that can be set, 100_00 is 100%
    uint256 public constant MAX_FEE = 100_00;
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    function __FeeManager_init(address defaultAdmin) public initializer {
        __AccessControl_init_unchained();
        __FeeManager_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    function __FeeManager_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IFeeManager
    function getTreasury() public view returns (address treasury) {
        return Storage.layout().treasury;
    }

    /// @inheritdoc IFeeManager
    function getStrategyActionFee(address strategy, IFeeManager.Action action) public view returns (uint256 fee) {
        return Storage.layout().strategyActionFee[strategy][action];
    }

    /// @inheritdoc IFeeManager
    function setTreasury(address treasury) external onlyRole(FEE_MANAGER_ROLE) {
        Storage.layout().treasury = treasury;
        emit TreasurySet(treasury);
    }

    /// @inheritdoc IFeeManager
    function setStrategyActionFee(address strategy, IFeeManager.Action action, uint256 fee)
        external
        onlyRole(FEE_MANAGER_ROLE)
    {
        // Check if fees are not higher than 100%
        if (fee > MAX_FEE) {
            revert FeeTooHigh(fee, MAX_FEE);
        }

        Storage.layout().strategyActionFee[strategy][action] = fee;
        emit StrategyActionFeeSet(strategy, action, fee);
    }

    // Calculates and charges fee based on action type
    function _chargeStrategyFee(address strategy, uint256 amount, IFeeManager.Action action)
        internal
        returns (uint256 amountAfterFee)
    {
        // Calculate deposit fee (always round up) and send it to treasury
        uint256 feeAmount = Math.mulDiv(amount, getStrategyActionFee(strategy, action), MAX_FEE, Math.Rounding.Ceil);

        // Emit event and explicit return statement
        emit FeeCharged(strategy, action, amount, feeAmount);
        return amount - feeAmount;
    }
}
