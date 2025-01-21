// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Id, IMorpho, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";

contract MorphoLendingAdapter is IMorphoLendingAdapter, Initializable {
    /// @inheritdoc IMorphoLendingAdapter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc IMorphoLendingAdapter
    IMorpho public immutable morpho;

    /// @inheritdoc IMorphoLendingAdapter
    Id public morphoMarketId;

    /// @inheritdoc IMorphoLendingAdapter
    MarketParams public marketParams;

    /// @dev The amount of decimals of the collateral asset
    uint8 internal collateralDecimals;

    /// @dev The amount of decimals of the debt asset
    uint8 internal debtDecimals;

    /// @dev Reverts if the caller is not the stored leverageManager address
    modifier onlyLeverageManager() {
        if (msg.sender != address(leverageManager)) revert Unauthorized();
        _;
    }

    /// @notice Creates a new Morpho lending adapter
    /// @param _leverageManager The Seamless ilm-v2 LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) {
        leverageManager = _leverageManager;
        morpho = _morpho;
    }

    /// @notice Initializes the Morpho lending adapter
    /// @param _morphoMarketId The Morpho market ID
    function initialize(Id _morphoMarketId) external initializer {
        morphoMarketId = _morphoMarketId;
        marketParams = morpho.idToMarketParams(_morphoMarketId);

        collateralDecimals = IERC20Metadata(marketParams.collateralToken).decimals();
        debtDecimals = IERC20Metadata(marketParams.loanToken).decimals();
    }

    /// @inheritdoc ILendingAdapter
    function getCollateralAsset() external view returns (IERC20 collateralAsset) {
        return IERC20(marketParams.collateralToken);
    }

    /// @inheritdoc ILendingAdapter
    function getDebtAsset() external view returns (IERC20 debtAsset) {
        return IERC20(marketParams.loanToken);
    }

    /// @inheritdoc ILendingAdapter
    function convertCollateralToDebtAsset(uint256 collateral) public view returns (uint256 debt) {
        // Morpho oracles return the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by ORACLE_PRICE_SCALE.
        // More specifically, the price is quoted in `ORACLE_PRICE_SCALE + loan token decimals - collateral token decimals` decimals of precision.
        uint256 collateralAssetPriceInDebtAsset = IOracle(marketParams.oracle).price();

        debt = _multiplyAndScale(
            collateral,
            collateralAssetPriceInDebtAsset,
            ORACLE_PRICE_SCALE,
            collateralDecimals,
            debtDecimals,
            Math.Rounding.Floor
        );
    }

    /// @inheritdoc ILendingAdapter
    function convertDebtToCollateralAsset(uint256 debt) external view returns (uint256 collateral) {
        // Morpho oracles return the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by ORACLE_PRICE_SCALE.
        // More specifically, the price is quoted in `ORACLE_PRICE_SCALE + loan token decimals - collateral token decimals` decimals of precision.
        uint256 collateralAssetPriceInDebtAsset = IOracle(marketParams.oracle).price();

        collateral = _multiplyAndScale(
            debt,
            ORACLE_PRICE_SCALE,
            collateralAssetPriceInDebtAsset,
            debtDecimals,
            collateralDecimals,
            Math.Rounding.Ceil
        );
    }

    /// @inheritdoc ILendingAdapter
    function getCollateral() public view returns (uint256 collateral) {
        collateral = MorphoLib.collateral(morpho, morphoMarketId, address(this));
    }

    /// @inheritdoc ILendingAdapter
    function getCollateralInDebtAsset() public view returns (uint256 collateral) {
        return convertCollateralToDebtAsset(getCollateral());
    }

    /// @inheritdoc ILendingAdapter
    function getDebt() public view returns (uint256 debt) {
        return MorphoBalancesLib.expectedBorrowAssets(morpho, marketParams, address(this));
    }

    /// @inheritdoc ILendingAdapter
    function getEquityInDebtAsset() external view returns (uint256 equity) {
        uint256 collateralInDebtAsset = getCollateralInDebtAsset();
        uint256 debt = getDebt();

        equity = collateralInDebtAsset > debt ? collateralInDebtAsset - debt : 0;
    }

    /// @inheritdoc ILendingAdapter
    function addCollateral(uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory _marketParams = marketParams;

        // Transfer the collateral from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(_marketParams.collateralToken), msg.sender, address(this), amount);

        // Supply the collateral to the Morpho market
        IERC20(_marketParams.collateralToken).approve(address(_morpho), amount);
        _morpho.supplyCollateral(_marketParams, amount, address(this), hex"");
    }

    /// @inheritdoc ILendingAdapter
    function removeCollateral(uint256 amount) external onlyLeverageManager {
        // Withdraw the collateral from the Morpho market and send it to msg.sender
        morpho.withdrawCollateral(marketParams, amount, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function borrow(uint256 amount) external onlyLeverageManager {
        // Borrow the debt asset from the Morpho market and send it to the caller
        morpho.borrow(marketParams, amount, 0, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function repay(uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory _marketParams = marketParams;

        // Transfer the debt asset from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(_marketParams.loanToken), msg.sender, address(this), amount);

        // Repay the debt asset to the Morpho market
        IERC20(_marketParams.loanToken).approve(address(_morpho), amount);
        _morpho.repay(_marketParams, amount, 0, address(this), hex"");
    }

    /// @dev Multiplies a value by (numerator / denominator) and scales it to the output decimals
    function _multiplyAndScale(
        uint256 value,
        uint256 numerator,
        uint256 denominator,
        uint256 inputDecimals,
        uint256 outputDecimals,
        Math.Rounding rounding
    ) internal pure returns (uint256 scaledAmount) {
        if (inputDecimals > outputDecimals) {
            // Scale down the input value
            uint256 scalingFactor = 10 ** (inputDecimals - outputDecimals);
            scaledAmount = Math.mulDiv(value, numerator, denominator * scalingFactor, rounding);
        } else if (inputDecimals < outputDecimals) {
            // Scale up the input value
            uint256 scalingFactor = 10 ** (outputDecimals - inputDecimals);
            scaledAmount = Math.mulDiv(value * scalingFactor, numerator, denominator, rounding);
        } else {
            // No scaling needed
            scaledAmount = Math.mulDiv(value, numerator, denominator, rounding);
        }
    }
}
