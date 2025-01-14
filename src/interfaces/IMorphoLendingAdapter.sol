// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ILendingAdapter} from "./ILendingAdapter.sol";
import {ILeverageManager} from "./ILeverageManager.sol";
import {IMorpho, MarketParams} from "./IMorpho.sol";

interface IMorphoLendingAdapter is ILendingAdapter {
    /// @notice Emitted when the Morpho lending adapter is initialized
    event Initialized(
        ILeverageManager indexed leverageManager, IMorpho indexed morpho, MarketParams indexed marketParams
    );

    /// @notice Error thrown when the caller is unauthorized to call a function
    error Unauthorized();

    /// @notice The Seamless ilm-v2 LeverageManager contract
    /// @return leverageManager The Seamless ilm-v2 LeverageManager contract
    function leverageManager() external view returns (ILeverageManager leverageManager);

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

    /// @notice Initializes the Morpho lending adapter
    /// @param _leverageManager The Seamless ilm-v2 LeverageManager contract
    /// @param _morpho Morpho core protocol contract
    /// @param _marketParams The market parameters of the Morpho lending pool
    function initialize(ILeverageManager _leverageManager, IMorpho _morpho, MarketParams memory _marketParams)
        external;
}
