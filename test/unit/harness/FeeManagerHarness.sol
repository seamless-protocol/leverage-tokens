// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManager} from "src/FeeManager.sol";

/// @notice Wrapper contract that exposes all internal functions ofFeeManager
contract FeeManagerHarness is FeeManager {
    function initialize(address defaultAdmin, address treasury) external initializer {
        __FeeManager_init(defaultAdmin, treasury);
    }

    function exposed_getFeeManagerStorageSlot() external pure returns (bytes32 slot) {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        assembly {
            slot := $.slot
        }
    }

    function exposed_computeTokenFee(ILeverageToken token, uint256 equityAmount, ExternalAction action)
        external
        view
        returns (uint256, uint256)
    {
        return _computeTokenFee(token, equityAmount, action);
    }

    function exposed_computeTreasuryFee(ExternalAction action, uint256 shares) external view returns (uint256) {
        return _computeTreasuryFee(action, shares);
    }

    function exposed_chargeTreasuryFee(ILeverageToken token, uint256 shares) external {
        _chargeTreasuryFee(token, shares);
    }

    function exposed_setLeverageTokenActionFee(ILeverageToken token, ExternalAction action, uint256 fee) external {
        _setLeverageTokenActionFee(token, action, fee);
    }

    function exposed_getAccruedManagementFee(ILeverageToken token) external view returns (uint256) {
        return _getAccruedManagementFee(token);
    }

    function exposed_getFeeAdjustedTotalSupply(ILeverageToken token) external view returns (uint256) {
        return _getFeeAdjustedTotalSupply(token);
    }

    function exposed_validateFee(uint256 fee) external pure {
        _validateFee(fee);
    }
}
