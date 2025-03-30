// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Id, IMorpho, MarketParams, Market, Position} from "@morpho-blue/interfaces/IMorpho.sol";
import {MAX_LIQUIDATION_INCENTIVE_FACTOR, LIQUIDATION_CURSOR} from "@morpho-blue/libraries/ConstantsLib.sol";
import {MathLib as MorphoMathLib} from "@morpho-blue/libraries/MathLib.sol";
import {UtilsLib as MorphoUtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";

contract MorphoLendingAdapter is IMorphoLendingAdapter, Initializable {
    uint256 internal constant WAD = 1e18;

    /// @inheritdoc IMorphoLendingAdapter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc IMorphoLendingAdapter
    IMorpho public immutable morpho;

    /// @inheritdoc IMorphoLendingAdapter
    Id public morphoMarketId;

    /// @inheritdoc IMorphoLendingAdapter
    MarketParams public marketParams;

    /// @inheritdoc IMorphoLendingAdapter
    address public authorizedCreator;

    /// @inheritdoc IMorphoLendingAdapter
    bool public isUsed;

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
    /// @param _authorizedCreator The authorized creator of this lending adapter. The authorized creator can create a
    /// new leverage token using this adapter on the LeverageManager
    function initialize(Id _morphoMarketId, address _authorizedCreator) external initializer {
        morphoMarketId = _morphoMarketId;
        marketParams = morpho.idToMarketParams(_morphoMarketId);

        authorizedCreator = _authorizedCreator;
    }

    /// @inheritdoc ILendingAdapter
    function postLeverageTokenCreation(address creator, address) external onlyLeverageManager {
        if (creator != authorizedCreator) revert Unauthorized();
        if (isUsed) revert LendingAdapterAlreadyInUse();
        isUsed = true;
    }

    /// @inheritdoc ILendingAdapter
    function getCollateralAsset() external view returns (IERC20) {
        return IERC20(marketParams.collateralToken);
    }

    /// @inheritdoc ILendingAdapter
    function getDebtAsset() external view returns (IERC20) {
        return IERC20(marketParams.loanToken);
    }

    /// @inheritdoc ILendingAdapter
    function convertCollateralToDebtAsset(uint256 collateral) public view returns (uint256) {
        // Morpho oracles return the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by ORACLE_PRICE_SCALE.
        // More specifically, the price is quoted in `ORACLE_PRICE_SCALE + loan token decimals - collateral token decimals` decimals of precision.
        uint256 collateralAssetPriceInDebtAsset = IOracle(marketParams.oracle).price();

        // The result is scaled down by ORACLE_PRICE_SCALE to accommodate the oracle's decimals of precision
        return Math.mulDiv(collateral, collateralAssetPriceInDebtAsset, ORACLE_PRICE_SCALE, Math.Rounding.Floor);
    }

    /// @inheritdoc ILendingAdapter
    function convertDebtToCollateralAsset(uint256 debt) public view returns (uint256) {
        // Morpho oracles return the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by ORACLE_PRICE_SCALE.
        // More specifically, the price is quoted in `ORACLE_PRICE_SCALE + loan token decimals - collateral token decimals` decimals of precision.
        uint256 collateralAssetPriceInDebtAsset = IOracle(marketParams.oracle).price();

        // The result is scaled up by ORACLE_PRICE_SCALE to accommodate the oracle's decimals of precision
        return Math.mulDiv(debt, ORACLE_PRICE_SCALE, collateralAssetPriceInDebtAsset, Math.Rounding.Ceil);
    }

    /// @inheritdoc ILendingAdapter
    function getCollateral() public view returns (uint256) {
        return MorphoLib.collateral(morpho, morphoMarketId, address(this));
    }

    /// @inheritdoc ILendingAdapter
    function getCollateralInDebtAsset() public view returns (uint256) {
        return convertCollateralToDebtAsset(getCollateral());
    }

    /// @inheritdoc ILendingAdapter
    function getDebt() public view returns (uint256) {
        return MorphoBalancesLib.expectedBorrowAssets(morpho, marketParams, address(this));
    }

    /// @inheritdoc ILendingAdapter
    function getEquityInCollateralAsset() external view returns (uint256) {
        uint256 collateral = getCollateral();
        uint256 debtInCollateralAsset = convertDebtToCollateralAsset(getDebt());

        return collateral > debtInCollateralAsset ? collateral - debtInCollateralAsset : 0;
    }

    /// @inheritdoc ILendingAdapter
    function getEquityInDebtAsset() external view returns (uint256) {
        uint256 collateralInDebtAsset = getCollateralInDebtAsset();
        uint256 debt = getDebt();

        return collateralInDebtAsset > debt ? collateralInDebtAsset - debt : 0;
    }

    /// @inheritdoc ILendingAdapter
    function getHealthFactor() external view returns (uint256) {
        uint256 borrowed = getDebt();
        uint256 collateral = getCollateral();
        uint256 collateralInDebtAsset = convertCollateralToDebtAsset(collateral);

        uint256 maxBorrow = Math.mulDiv(collateralInDebtAsset, marketParams.lltv, WAD, Math.Rounding.Floor);

        if (borrowed == 0) return type(uint256).max;

        return Math.mulDiv(maxBorrow, WAD, borrowed, Math.Rounding.Floor);
    }

    /// @inheritdoc ILendingAdapter
    function getLiquidationPenalty() external view returns (uint256) {
        uint256 liquidationIncentiveFactor = MorphoUtilsLib.min(
            MAX_LIQUIDATION_INCENTIVE_FACTOR,
            MorphoMathLib.wDivDown(WAD, WAD - MorphoMathLib.wMulDown(LIQUIDATION_CURSOR, WAD - marketParams.lltv))
        );

        return liquidationIncentiveFactor - WAD;
    }

    /// @inheritdoc ILendingAdapter
    function addCollateral(uint256 amount) external {
        if (amount == 0) return;

        MarketParams memory _marketParams = marketParams;

        // Transfer the collateral from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(_marketParams.collateralToken), msg.sender, address(this), amount);

        // Supply the collateral to the Morpho market
        IERC20(_marketParams.collateralToken).approve(address(morpho), amount);
        morpho.supplyCollateral(_marketParams, amount, address(this), hex"");
    }

    /// @inheritdoc ILendingAdapter
    function removeCollateral(uint256 amount) external onlyLeverageManager {
        if (amount == 0) return;
        // Withdraw the collateral from the Morpho market and send it to msg.sender
        morpho.withdrawCollateral(marketParams, amount, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function borrow(uint256 amount) external onlyLeverageManager {
        if (amount == 0) return;
        // Borrow the debt asset from the Morpho market and send it to the caller
        morpho.borrow(marketParams, amount, 0, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function repay(uint256 amount) external {
        if (amount == 0) return;

        MarketParams memory _marketParams = marketParams;

        // Transfer the debt asset from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(_marketParams.loanToken), msg.sender, address(this), amount);

        // Accrue interest before repaying to make sure interest is included in calculation
        morpho.accrueInterest(marketParams);

        // Fetch total borrow assets and total borrow shares. This data is updated because we accrued interest in previous step
        Market memory market = morpho.market(morphoMarketId);
        uint256 totalBorrowAssets = market.totalBorrowAssets;
        uint256 totalBorrowShares = market.totalBorrowShares;

        // Fetch how much borrow shares do we owe
        Position memory position = morpho.position(morphoMarketId, address(this));
        uint256 maxSharesToRepay = position.borrowShares;
        uint256 maxAssetsToRepay = SharesMathLib.toAssetsUp(maxSharesToRepay, totalBorrowAssets, totalBorrowShares);

        IERC20(_marketParams.loanToken).approve(address(morpho), amount);

        // Repay all shares if we are trying to repay more assets than we owe
        if (amount >= maxAssetsToRepay) {
            morpho.repay(_marketParams, 0, maxSharesToRepay, address(this), hex"");
        } else {
            morpho.repay(_marketParams, amount, 0, address(this), hex"");
        }
    }
}
