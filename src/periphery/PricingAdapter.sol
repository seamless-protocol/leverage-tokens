// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IAggregatorV2V3Interface} from "../interfaces/periphery/IAggregatorV2V3Interface.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {IPricingAdapter} from "../interfaces/periphery/IPricingAdapter.sol";

/// @custom:contact security@seamlessprotocol.com
contract PricingAdapter is IPricingAdapter {
    uint256 internal constant WAD = 1e18;

    /// @inheritdoc IPricingAdapter
    ILeverageManager public immutable leverageManager;

    /// @notice Constructor
    /// @param _leverageManager The LeverageManager contract
    constructor(ILeverageManager _leverageManager) {
        leverageManager = _leverageManager;
    }

    /// @inheritdoc IPricingAdapter
    function getLeverageTokenPriceInCollateral(ILeverageToken leverageToken) public view returns (uint256) {
        if (leverageToken.totalSupply() == 0) {
            return 0;
        }

        uint256 collateralPerShare = leverageManager.convertSharesToCollateral(leverageToken, WAD, Math.Rounding.Floor);
        uint256 debtPerShare = leverageManager.convertSharesToDebt(leverageToken, WAD, Math.Rounding.Ceil);

        uint256 debtPerShareInCollateralAsset =
            leverageManager.getLeverageTokenLendingAdapter(leverageToken).convertDebtToCollateralAsset(debtPerShare);

        uint256 equityInCollateralPerShare =
            collateralPerShare > debtPerShareInCollateralAsset ? collateralPerShare - debtPerShareInCollateralAsset : 0;

        return equityInCollateralPerShare;
    }

    /// @inheritdoc IPricingAdapter
    function getLeverageTokenPriceInDebt(ILeverageToken leverageToken) public view returns (uint256) {
        if (leverageToken.totalSupply() == 0) {
            return 0;
        }

        uint256 collateralPerShare = leverageManager.convertSharesToCollateral(leverageToken, WAD, Math.Rounding.Floor);
        uint256 debtPerShare = leverageManager.convertSharesToDebt(leverageToken, WAD, Math.Rounding.Ceil);

        uint256 collateralPerShareInDebtAsset = leverageManager.getLeverageTokenLendingAdapter(leverageToken)
            .convertCollateralToDebtAsset(collateralPerShare);

        uint256 equityInDebtPerShare =
            collateralPerShareInDebtAsset > debtPerShare ? collateralPerShareInDebtAsset - debtPerShare : 0;

        return equityInDebtPerShare;
    }

    /// @inheritdoc IPricingAdapter
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
