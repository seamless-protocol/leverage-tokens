// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV2V3Interface} from "../interfaces/periphery/IAggregatorV2V3Interface.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";

contract LeverageTokenLens {
    uint256 public constant WAD = 1e18;

    /// @notice The LeverageManager contract
    ILeverageManager public immutable leverageManager;

    /// @notice Constructor
    /// @param _leverageManager The LeverageManager contract
    constructor(ILeverageManager _leverageManager) {
        leverageManager = _leverageManager;
    }

    /// @notice Returns the price of one LeverageToken (1e18 wei) denominated in collateral asset of the LeverageToken
    /// @param leverageToken The LeverageToken to get the price for
    /// @return price The price of one LeverageToken denominated in collateral asset
    function getLeverageTokenPriceInCollateral(ILeverageToken leverageToken) public view returns (uint256) {
        uint256 totalSupply = leverageToken.totalSupply();

        if (totalSupply == 0) {
            return 0;
        }

        uint256 totalCollateral = leverageManager.getLeverageTokenLendingAdapter(leverageToken).getCollateral();
        return (WAD * totalCollateral) / totalSupply;
    }

    /// @notice Returns the price of one LeverageToken (1e18 wei) denominated in debt asset of the LeverageToken
    /// @param leverageToken The LeverageToken to get the price for
    /// @return price The price of one LeverageToken denominated in debt asset
    function getLeverageTokenPriceInDebt(ILeverageToken leverageToken) public view returns (uint256) {
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(leverageToken);
        uint256 priceInCollateral = getLeverageTokenPriceInCollateral(leverageToken);
        return lendingAdapter.convertCollateralToDebtAsset(priceInCollateral);
    }

    /// @notice Returns the price of one LeverageToken (1e18 wei) adjusted to the price on the Chainlink oracle
    /// @param leverageToken The LeverageToken to get the price for
    /// @param chainlinkOracle The Chainlink oracle to use for pricing
    /// @param isBaseDebtAsset True if the debt asset is the base asset of the Chainlink oracle
    /// @return price The price of one LeverageToken adjusted to the price on the Chainlink oracle, in the decimals of the oracle
    function getLeverageTokenPriceAdjusted(
        ILeverageToken leverageToken,
        IAggregatorV2V3Interface chainlinkOracle,
        bool isBaseDebtAsset
    ) public view returns (int256) {
        uint256 priceInBaseAsset = isBaseDebtAsset
            ? getLeverageTokenPriceInDebt(leverageToken)
            : getLeverageTokenPriceInCollateral(leverageToken);
        uint256 baseAssetDecimals = isBaseDebtAsset
            ? IERC20Metadata(address(leverageManager.getLeverageTokenDebtAsset(leverageToken))).decimals()
            : IERC20Metadata(address(leverageManager.getLeverageTokenCollateralAsset(leverageToken))).decimals();

        uint256 oraclePrice = uint256(chainlinkOracle.latestAnswer());

        uint256 adjustedPrice = (oraclePrice * priceInBaseAsset) / 10 ** baseAssetDecimals;

        return int256(adjustedPrice);
    }
}
