// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Id, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILendingAdapter} from "./ILendingAdapter.sol";
import {ILeverageManager} from "./ILeverageManager.sol";

interface IMorphoLendingAdapter is ILendingAdapter {
    /// @notice The error emitted when the lending adapter is already initialized
    error AlreadyInitialized();

    /// @notice Emitted when the lending adapter is initialized
    event Initialized(Id indexed morphoMarketId);

    /// @notice Whether the lending adapter is initialized
    /// @return initialized Whether the lending adapter is initialized
    function initialized() external view returns (bool initialized);

    /// @notice The Seamless ilm-v2 LeverageManager contract
    /// @return leverageManager The Seamless ilm-v2 LeverageManager contract
    function leverageManager() external view returns (ILeverageManager leverageManager);

    /// @notice The ID of the Morpho market that the lending adapter manages a position in
    /// @return morphoMarketId The ID of the Morpho market that the lending adapter manages a position in
    function morphoMarketId() external view returns (Id morphoMarketId);

    /// @notice The market parameters of the Morpho lending pool
    /// @return loanToken The loan token of the Morpho lending pool
    /// @return collateralToken The collateral token of the Morpho lending pool
    /// @return oracle The oracle of the Morpho lending pool
    /// @return irm The IRM of the Morpho lending pool
    /// @return lltv The LLTV of the Morpho lending pool
    function marketParams()
        external
        view
        returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);

    /// @notice The Morpho core protocol contract
    /// @return morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho morpho);

    /// @notice Initialize the lending adapter
    /// @param morphoMarketId_ The ID of the Morpho market that the lending adapter manages a position in
    function initialize(Id morphoMarketId_) external;
}
