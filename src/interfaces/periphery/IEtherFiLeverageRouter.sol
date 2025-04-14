// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {IEtherFiL2ModeSyncPoolETH} from "./IEtherFiL2ModeSyncPoolETH.sol";
import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";

interface IEtherFiLeverageRouter {
    /// @notice Error thrown when the caller is not authorized to execute a function
    error Unauthorized();

    /// @notice The EtherFi L2 Mode Sync Pool contract
    /// @return _etherFiL2ModeSyncPoolETH The EtherFi L2 Mode Sync Pool contract
    function etherFiL2ModeSyncPoolETH() external view returns (IEtherFiL2ModeSyncPoolETH _etherFiL2ModeSyncPoolETH);

    /// @notice The LeverageManager contract
    /// @return _leverageManager The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Morpho core protocol contract
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);

    /// @notice Deposit equity into a LeverageToken that uses weETH as collateral and WETH as debt
    /// @param token LeverageToken to deposit equity into
    /// @param equityInCollateralAsset The amount of weETH equity to deposit into the LeverageToken.
    /// @param minShares Minimum shares (LeverageTokens) to receive from the deposit
    /// @dev Transfers `equityInCollateralAsset` of weETH to the LeverageRouter, flash loans the additional weETH collateral
    ///      required to add the equity to the LeverageToken, receives WETH debt, then unwraps the WETH debt to ETH and deposits
    ///      the ETH into the EtherFi L2 Mode Sync Pool to obtain weETH. The received weETH is used to repay the flash loan
    function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares) external;
}
