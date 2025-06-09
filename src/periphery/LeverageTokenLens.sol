// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV2V3Interface} from "../interfaces/periphery/IAggregatorV2V3Interface.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageTokenLens} from "../interfaces/periphery/ILeverageTokenLens.sol";

contract LeverageTokenLens is ILeverageTokenLens {
    uint256 internal constant WAD = 1e18;

    /// @inheritdoc ILeverageTokenLens
    ILeverageManager public immutable leverageManager;

    /// @notice Constructor
    /// @param _leverageManager The LeverageManager contract
    constructor(ILeverageManager _leverageManager) {
        leverageManager = _leverageManager;
    }

    /// @inheritdoc ILeverageTokenLens
    function getLeverageTokenPriceInCollateral(ILeverageToken leverageToken) public view returns (uint256) {
        uint256 totalSupply = leverageToken.totalSupply();

        if (totalSupply == 0) {
            return 0;
        }

        uint256 totalCollateral = leverageManager.getLeverageTokenLendingAdapter(leverageToken).getCollateral();
        return (WAD * totalCollateral) / totalSupply;
    }

    /// @inheritdoc ILeverageTokenLens
    function getLeverageTokenPriceInDebt(ILeverageToken leverageToken) public view returns (uint256) {
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(leverageToken);
        uint256 priceInCollateral = getLeverageTokenPriceInCollateral(leverageToken);
        return lendingAdapter.convertCollateralToDebtAsset(priceInCollateral);
    }

    /// @inheritdoc ILeverageTokenLens
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

        int256 oraclePrice = chainlinkOracle.latestAnswer();

        int256 adjustedPrice = (oraclePrice * int256(priceInBaseAsset)) / int256(10 ** baseAssetDecimals);

        return adjustedPrice;
    }
}
