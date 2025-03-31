// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Id, IMorpho, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {IPreLiquidationLendingAdapter} from "./IPreLiquidationLendingAdapter.sol";
import {ILeverageManager} from "./ILeverageManager.sol";

interface IMorphoLendingAdapter is IPreLiquidationLendingAdapter {
    /// @notice Event emitted when the Morpho lending adapter is initialized
    event MorphoLendingAdapterInitialized(Id morphoMarketId, MarketParams marketParams, address authorizedCreator);

    /// @notice Event emitted when the Morpho lending adapter is flagged as used in post leverage token creation
    event MorphoLendingAdapterUsed();

    /// @notice Thrown when someone tries to create leverage token with this lending adapter but it is already in use
    error LendingAdapterAlreadyInUse();

    /// @notice The authorized creator of the lending adapter
    /// @return _authorizedCreator The authorized creator of the lending adapter
    /// @dev Only the authorized creator can create a new leverage token using this adapter on the LeverageManager
    function authorizedCreator() external view returns (address _authorizedCreator);

    /// @notice Whether the lending adapter is in use
    /// @return _isUsed Whether the lending adapter is in use
    /// @dev If this is true, the lending adapter cannot be used to create a new leverage token
    function isUsed() external view returns (bool _isUsed);

    /// @notice The Seamless ilm-v2 LeverageManager contract
    /// @return _leverageManager The Seamless ilm-v2 LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The ID of the Morpho market that the lending adapter manages a position in
    /// @return _morphoMarketId The ID of the Morpho market that the lending adapter manages a position in
    function morphoMarketId() external view returns (Id _morphoMarketId);

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
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);
}
