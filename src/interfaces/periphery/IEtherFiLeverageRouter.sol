// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Internal imports
import {IEtherFiL2ModeSyncPool} from "./IEtherFiL2ModeSyncPool.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {ILeverageRouterBase} from "./ILeverageRouterBase.sol";

interface IEtherFiLeverageRouter is ILeverageRouterBase {
    /// @notice The EtherFi L2 Mode Sync Pool contract
    /// @return _etherFiL2ModeSyncPool The EtherFi L2 Mode Sync Pool contract
    function etherFiL2ModeSyncPool() external view returns (IEtherFiL2ModeSyncPool _etherFiL2ModeSyncPool);

    /// @notice Deposit equity into a LeverageToken that uses weETH as collateral and WETH as debt
    /// @param token LeverageToken to deposit equity into
    /// @param equityInCollateralAsset The amount of weETH equity to deposit into the LeverageToken.
    /// @param minShares Minimum shares (LeverageTokens) to receive from the deposit
    /// @dev Transfers `equityInCollateralAsset` of weETH to the LeverageRouter, flash loans the additional weETH collateral
    ///      required to add the equity to the LeverageToken, receives WETH debt, then unwraps the WETH debt to ETH and deposits
    ///      the ETH into the EtherFi L2 Mode Sync Pool to obtain weETH. The received weETH is used to repay the flash loan
    function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares) external;
}
