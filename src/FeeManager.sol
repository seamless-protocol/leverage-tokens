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
        /// @dev Treasury address that receives treasury fees
        address treasury;
        /// @dev Treasury fee for each action
        mapping(ExternalAction action => uint256) treasuryActionFee;
        /// @dev Strategy address => Action => Fee
        mapping(IStrategy strategy => mapping(ExternalAction action => uint256)) strategyActionFee;
    }

    function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
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
    function getStrategyActionFee(IStrategy strategy, ExternalAction action) public view returns (uint256 fee) {
        return _getFeeManagerStorage().strategyActionFee[strategy][action];
    }

    /// @inheritdoc IFeeManager
    function getTreasury() public view returns (address treasury) {
        return _getFeeManagerStorage().treasury;
    }

    /// @inheritdoc IFeeManager
    function getTreasuryActionFee(ExternalAction action) public view returns (uint256 fee) {
        return _getFeeManagerStorage().treasuryActionFee[action];
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

    /// @inheritdoc IFeeManager
    function setTreasury(address treasury) external onlyRole(FEE_MANAGER_ROLE) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.treasury = treasury;

        // If the treasury is reset, the treasury fees should be reset as well
        if (treasury == address(0)) {
            $.treasuryActionFee[ExternalAction.Deposit] = 0;
            $.treasuryActionFee[ExternalAction.Withdraw] = 0;
        }

        emit TreasurySet(treasury);
    }

    /// @inheritdoc IFeeManager
    function setTreasuryActionFee(ExternalAction action, uint256 fee) external onlyRole(FEE_MANAGER_ROLE) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        if (fee > MAX_FEE) {
            revert FeeTooHigh(fee, MAX_FEE);
        }

        if ($.treasury == address(0)) {
            revert TreasuryNotSet();
        }

        $.treasuryActionFee[action] = fee;
        emit TreasuryActionFeeSet(action, fee);
    }

    /// @notice Computes equity fees based on action
    /// @param strategy Strategy to compute fees for
    /// @param equity Amount of equity to compute fees for, denominated in collateral asset
    /// @param action Action to compute fees for, Deposit or Withdraw
    /// @return equityToCover Equity to add / remove from the strategy after fees, denominated in collateral asset
    /// @return equityForShares Equity to mint / burn shares for from the strategy after fees, denominated in collateral asset
    /// @return strategyFee Strategy fee amount, denominated in collateral asset
    /// @return treasuryFee Treasury fee amount, denominated in collateral asset
    /// @dev Fees are always rounded up.
    /// @dev If the sum of the strategy fee and the treasury fee is greater than the amount,
    ///      the strategy fee is set to the delta of the amount and the treasury fee.
    function _computeEquityFees(IStrategy strategy, uint256 equity, ExternalAction action)
        internal
        view
        returns (uint256, uint256, uint256, uint256)
    {
        // A treasury fee is only applied if the treasury is set
        uint256 treasuryFee = Math.mulDiv(equity, getTreasuryActionFee(action), MAX_FEE, Math.Rounding.Ceil);
        uint256 strategyFee = Math.mulDiv(equity, getStrategyActionFee(strategy, action), MAX_FEE, Math.Rounding.Ceil);

        // If the sum of the strategy fee and the treasury fee is greater than the equity amount,
        // the strategy fee is set to the delta of the equity amount and the treasury fee.
        strategyFee = Math.min(strategyFee, equity - treasuryFee);

        // For the collateral and debt required by the position held by the strategy for the action, we need to use
        // the equity amount without the strategy fee applied because the strategy fee is used to increase share value
        // among existing strategy shares. So, the strategy fee is applied on the shares received / burned but not on
        // the collateral supplied / removed and debt borrowed / repaid.
        //
        // For deposits we need to subtract the treasury fee from the equity amount used for the calculation of the
        // collateral and debt because the treasury fee should not be supplied to the position held by the strategy,
        // it should be simply transferred to the treasury.
        //
        // For withdrawals, the treasury fee should be included in the calculation of the collateral and debt because
        // it comes from the collateral removed from the position held by the strategy.
        uint256 equityToCover = action == ExternalAction.Deposit ? equity - treasuryFee : equity;

        // To increase share value for existing users, less shares are minted on deposits and more shares are burned on
        // withdrawals.
        uint256 equityForShares =
            action == ExternalAction.Deposit ? equityToCover - strategyFee : equityToCover + strategyFee;

        return (equityToCover, equityForShares, strategyFee, treasuryFee);
    }

    /// @notice Charges a treasury fee if the treasury is set
    /// @param collateralAsset Collateral asset to charge the fee from
    /// @param amount Amount of fee to charge
    function _chargeTreasuryFee(IERC20 collateralAsset, uint256 amount) internal {
        address treasury = getTreasury();
        if (treasury != address(0)) {
            SafeERC20.safeTransfer(collateralAsset, treasury, amount);
        }
    }
}
