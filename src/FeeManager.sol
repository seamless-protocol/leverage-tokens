// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";

/**
 * @dev The FeeManager contract is an upgradeable core contract that is responsible for managing the fees for LeverageTokens.
 * There are three types of fees:
 *   - Token action fees: Fees charged that accumulate towards the value of the LeverageToken for current LeverageToken
 *     holders, applied on equity for deposits and withdrawals
 *   - Treasury action fees: Fees charged in shares that are transferred to the configured treasury address, applied on
 *     shares minted for deposits and shares burned for withdrawals
 *   - Management fees: Fees charged in shares that are transferred to the configured treasury address. The management fee
 *     accrues linearly over time and is minted to the treasury when the `chargeManagementFee` function is executed
 *
 * The maximum fee that can be set for each action is 100_00 (100%).
 */
contract FeeManager is IFeeManager, Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    uint256 internal constant MAX_FEE = 100_00;

    uint256 internal constant SECS_PER_YEAR = 31536000;

    /// @dev Struct containing all state for the FeeManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.FeeManager
    struct FeeManagerStorage {
        /// @dev Treasury address that receives treasury fees and management fees
        address treasury;
        /// @dev Annual management fee. 100_00 is 100% per year
        uint256 managementFee;
        /// @dev Timestamp when the management fee was most recently accrued for each LeverageToken
        mapping(ILeverageToken token => uint120) lastManagementFeeAccrualTimestamp;
        /// @dev Treasury action fee for each action. 100_00 is 100%
        mapping(ExternalAction action => uint256) treasuryActionFee;
        /// @dev Token action fee for each action. 100_00 is 100%
        mapping(ILeverageToken token => mapping(ExternalAction action => uint256)) tokenActionFee;
    }

    function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x6c0d8f7f1305f10aa51c80093531513ff85a99140b414f68890d41ac36949e00
        }
    }

    function __FeeManager_init(address defaultAdmin) public onlyInitializing {
        __AccessControl_init_unchained();
        __ReentrancyGuard_init_unchained();
        __FeeManager_init_unchained(defaultAdmin);
    }

    function __FeeManager_init_unchained(address defaultAdmin) internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /// @inheritdoc IFeeManager
    function getLastManagementFeeAccrualTimestamp(ILeverageToken token) public view returns (uint120) {
        return _getFeeManagerStorage().lastManagementFeeAccrualTimestamp[token];
    }

    /// @inheritdoc IFeeManager
    function getLeverageTokenActionFee(ILeverageToken token, ExternalAction action) public view returns (uint256 fee) {
        return _getFeeManagerStorage().tokenActionFee[token][action];
    }

    /// @inheritdoc IFeeManager
    function getManagementFee() public view returns (uint256 fee) {
        return _getFeeManagerStorage().managementFee;
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
    function setManagementFee(uint128 fee) external onlyRole(FEE_MANAGER_ROLE) {
        _validateFee(fee);

        _getFeeManagerStorage().managementFee = fee;
        emit ManagementFeeSet(fee);
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
        _validateFee(fee);
        if (getTreasury() == address(0)) {
            revert TreasuryNotSet();
        }

        _getFeeManagerStorage().treasuryActionFee[action] = fee;

        emit TreasuryActionFeeSet(action, fee);
    }

    /// @inheritdoc IFeeManager
    function chargeManagementFee(ILeverageToken token) public {
        address treasury = getTreasury();

        // If the treasury is not set, do nothing. Management fee will continue to accrue
        // but cannot be minted until the treasury is set
        if (treasury == address(0)) {
            return;
        }

        // Shares fee must be obtained before the last management fee accrual timestamp is updated
        uint256 sharesFee = _getAccruedManagementFee(token);
        _getFeeManagerStorage().lastManagementFeeAccrualTimestamp[token] = uint120(block.timestamp);

        token.mint(treasury, sharesFee);
        emit ManagementFeeCharged(token, sharesFee);
    }

    /// @notice Function that mints shares to the treasury for the treasury fee, if the treasury is set
    /// @param token LeverageToken to mint shares to treasury for
    /// @param shares Shares to mint
    /// @dev If the treasury is not set, this function does not mint any shares and does not revert
    /// @dev This contract must be authorized to mint shares for the LeverageToken
    function _chargeTreasuryFee(ILeverageToken token, uint256 shares) internal {
        address treasury = getTreasury();
        if (treasury != address(0)) {
            token.mint(treasury, shares);
        }
    }

    /// @notice Computes equity fees based on action
    /// @param token LeverageToken to compute equity fees for
    /// @param equity Amount of equity to compute fees for, denominated in collateral asset
    /// @param action Action to compute fees for, Deposit or Withdraw
    /// @return equityForShares Equity to mint / burn shares for the LeverageToken after fees, denominated in the collateral asset of the LeverageToken
    /// @return tokenFee LeverageToken equity fee amount, denominated in the collateral asset of the LeverageToken
    /// @dev Fees are always rounded up.
    function _computeEquityFees(ILeverageToken token, uint256 equity, ExternalAction action)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 tokenFee = Math.mulDiv(equity, getLeverageTokenActionFee(token, action), MAX_FEE, Math.Rounding.Ceil);

        // To increase share value for existing users, less shares are minted on deposits and more shares are burned on
        // withdrawals by subtracting the token fee from the equity on deposits and adding the token fee to the equity on
        // withdrawals.
        uint256 equityForShares = action == ExternalAction.Deposit ? equity - tokenFee : equity + tokenFee;

        return (equityForShares, tokenFee);
    }

    /// @notice Computes the treasury action fee for a given action
    /// @param action Action to compute treasury action fee for
    /// @param shares Shares to compute treasury action fee for
    /// @return treasuryFee Treasury action fee amount in shares
    /// @dev If the treasury is not set, this function returns 0
    function _computeTreasuryFee(ExternalAction action, uint256 shares) internal view returns (uint256) {
        if (getTreasury() == address(0)) {
            return 0;
        }

        return Math.mulDiv(shares, getTreasuryActionFee(action), MAX_FEE, Math.Rounding.Ceil);
    }

    /// @notice Function that returns the total supply of the LeverageToken adjusted for any accrued management fees
    /// @param token LeverageToken to get fee adjusted total supply for
    /// @return totalSupply Fee adjusted total supply of the LeverageToken
    function _getFeeAdjustedTotalSupply(ILeverageToken token) internal view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 accruedManagementFee = _getAccruedManagementFee(token);
        return totalSupply + accruedManagementFee;
    }

    /// @notice Function that calculates how many shares to mint for the accrued management fee at the current timestamp
    /// @param token LeverageToken to calculate management fee shares for
    /// @return shares Shares to mint
    function _getAccruedManagementFee(ILeverageToken token) internal view returns (uint256) {
        uint256 managementFee = getManagementFee();
        uint120 lastManagementFeeAccrualTimestamp = getLastManagementFeeAccrualTimestamp(token);
        uint256 totalSupply = token.totalSupply();

        uint256 duration = block.timestamp - lastManagementFeeAccrualTimestamp;

        uint256 sharesFee =
            Math.mulDiv(managementFee * totalSupply, duration, MAX_FEE * SECS_PER_YEAR, Math.Rounding.Ceil);
        return sharesFee;
    }

    /// @notice Sets the LeverageToken fee for a specific action
    /// @param token LeverageToken to set fee for
    /// @param action Action to set fee for
    /// @param fee Fee for action, 100_00 is 100%
    /// @dev If caller tries to set fee above 100% it reverts with FeeTooHigh error
    function _setLeverageTokenActionFee(ILeverageToken token, ExternalAction action, uint256 fee) internal {
        _validateFee(fee);

        _getFeeManagerStorage().tokenActionFee[token][action] = fee;
        emit LeverageTokenActionFeeSet(token, action, fee);
    }

    /// @notice Validates that the fee is not higher than 100%
    /// @param fee Fee to validate
    function _validateFee(uint256 fee) internal pure {
        if (fee > MAX_FEE) {
            revert FeeTooHigh(fee, MAX_FEE);
        }
    }
}
