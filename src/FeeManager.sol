// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";

contract FeeManager is IFeeManager, Initializable, AccessControlUpgradeable {
    // Max fee that can be set, 100_00 is 100%
    uint256 public constant MAX_FEE = 100_00;
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    /// @dev Struct containing all state for the FeeManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.FeeManager
    struct FeeManagerStorage {
        /// @dev Treasury address that receives all the fees
        address treasury;
        /// @dev Strategy address => Action => Fee
        mapping(IStrategy strategy => mapping(ExternalAction action => uint256)) strategyActionFee;
    }

    function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.FeeManagerStorage")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x6c0d8f7f1305f10aa51c80093531513ff85a99140b414f68890d41ac36949e00
        }
    }

    function __FeeManager_init(address defaultAdmin) public initializer {
        __AccessControl_init_unchained();
        __FeeManager_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    function __FeeManager_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IFeeManager
    function getTreasury() public view returns (address treasury) {
        return _getFeeManagerStorage().treasury;
    }

    /// @inheritdoc IFeeManager
    function getStrategyActionFee(IStrategy strategy, ExternalAction action) public view returns (uint256 fee) {
        return _getFeeManagerStorage().strategyActionFee[strategy][action];
    }

    /// @inheritdoc IFeeManager
    function setTreasury(address treasury) external onlyRole(FEE_MANAGER_ROLE) {
        _getFeeManagerStorage().treasury = treasury;
        emit TreasurySet(treasury);
    }

    /// @inheritdoc IFeeManager
    function setStrategyActionFee(IStrategy strategy, ExternalAction action, uint256 fee)
        external
        onlyRole(FEE_MANAGER_ROLE)
    {
        // Check if fees are not higher than 100%
        if (fee > MAX_FEE) {
            revert FeeTooHigh(fee, MAX_FEE);
        }

        _getFeeManagerStorage().strategyActionFee[strategy][action] = fee;
        emit StrategyActionFeeSet(strategy, action, fee);
    }

    /// @notice Computes fee based on user action
    /// @param strategy Strategy to compute fee for
    /// @param amount Shares to charge fee on
    /// @param action Action to compute fee for, Deposit or Withdraw
    /// @return amountAfterFee Shares amount after fee
    /// @return feeAmount Fee amount in shares
    /// @dev Fee is always rounded up.
    ///      If action is deposit, fee is subtracted from amount, if action is withdraw, fee is added to amount.
    ///      Which means that on deposit user will receive less shares and on withdraw more shares will be burned from user
    function _computeFeeAdjustedShares(IStrategy strategy, uint256 amount, ExternalAction action)
        internal
        view
        returns (uint256, uint256)
    {
        // Calculate deposit fee (always round up) and send it to treasury
        uint256 feeAmount = Math.mulDiv(amount, getStrategyActionFee(strategy, action), MAX_FEE, Math.Rounding.Ceil);
        uint256 amountAfterFee = action == ExternalAction.Deposit ? amount - feeAmount : amount + feeAmount;
        return (amountAfterFee, feeAmount);
    }
}
