// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IAggregatorV2V3Interface} from "../interfaces/periphery/IAggregatorV2V3Interface.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {IPricingAdapter} from "../interfaces/periphery/IPricingAdapter.sol";

/**
 * @dev This contract is used to get the price of a LeverageToken in the collateral asset of the LeverageToken, debt asset
 * of the LeverageToken, or the price using a Chainlink oracle.
 * The decimal precision of the price using a Chainlink oracle is equal to the decimals of the base asset of the Chainlink
 * oracle.
 * Integrators using this PricingAdapter should carefully evaluate and understand the risks of using this contract before
 * using it. Some points to consider are the rounding direction and precision used by the logic in this contract.
 *
 * @custom:contact security@seamlessprotocol.com
 */
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
        uint256 totalSupply = leverageManager.getFeeAdjustedTotalSupply(leverageToken);

        if (totalSupply == 0) {
            return 0;
        }

        uint256 totalEquityInCollateralAsset =
            leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInCollateralAsset();

        // LT is on 18 decimals, so 1 LT is WAD wei
        return (WAD * totalEquityInCollateralAsset) / totalSupply;
    }

    /// @inheritdoc IPricingAdapter
    function getLeverageTokenPriceInDebt(ILeverageToken leverageToken) public view returns (uint256) {
        uint256 totalSupply = leverageManager.getFeeAdjustedTotalSupply(leverageToken);

        if (totalSupply == 0) {
            return 0;
        }

        uint256 totalEquityInDebtAsset =
            leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInDebtAsset();

        // LT is on 18 decimals, so 1 LT is WAD wei
        return (WAD * totalEquityInDebtAsset) / totalSupply;
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

        int256 oraclePrice = chainlinkOracle.latestAnswer();
        uint256 oracleDecimals = chainlinkOracle.decimals();

        int256 adjustedPrice = (oraclePrice * int256(priceInBaseAsset)) / int256(10 ** oracleDecimals);

        return adjustedPrice;
    }
}
