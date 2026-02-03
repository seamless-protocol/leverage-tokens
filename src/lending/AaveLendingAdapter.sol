// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IAaveLendingAdapter} from "src/interfaces/IAaveLendingAdapter.sol";
import {IPreLiquidationLendingAdapter} from "src/interfaces/IPreLiquidationLendingAdapter.sol";

// Aave v3 imports
import {IPool} from "@aave-v3-origin/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@aave-v3-origin/contracts/interfaces/IAaveOracle.sol";
import {DataTypes} from "@aave-v3-origin/contracts/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "@aave-v3-origin/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

/**
 * @title AaveLendingAdapter
 * @notice Adapter to interface with Aave v3 markets for LeverageTokens
 * @dev LeverageToken creators can configure their LeverageToken to use an AaveLendingAdapter
 * to use Aave as the lending protocol for their LeverageToken.
 *
 * COMPATIBILITY: This adapter requires Aave v3.1+ (aave-v3-origin). It uses functions like
 * `getEModeCategoryLtvzeroBitmap()` that are not available in earlier Aave v3.0.x deployments.
 *
 * The AaveLendingAdapter uses Aave's oracle to convert between the collateral and debt asset.
 * It supports Aave's E-Mode for correlated assets like ETH/stETH pairs, which enables higher
 * capital efficiency.
 *
 * SECURITY NOTE: This adapter deliberately does NOT use Aave's aggregated position functions
 * (like `getUserAccountData()`) to determine position state. Instead, it tracks collateral and
 * debt using the specific aToken and variableDebtToken balances for the configured assets only.
 *
 * This design protects against manipulation via "foreign collateral donations" - where someone
 * supplies a different asset on behalf of this adapter in Aave. Such donations would affect
 * Aave's aggregated position calculations but do NOT affect this adapter's view of its position.
 * Foreign collateral can be rescued using `rescueForeignCollateral()`.
 *
 * Note: `getDebt` returns the current variable debt balance which includes accrued interest.
 *
 * @custom:contact security@seamlessprotocol.com
 */
contract AaveLendingAdapter is IAaveLendingAdapter, Initializable {
    /// @dev Variable interest rate mode in Aave
    uint256 internal constant VARIABLE_INTEREST_RATE_MODE = 2;

    /// @dev Base for percentage calculations (100% = 10000)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    /// @dev WAD for 1e18 calculations
    uint256 internal constant WAD = 1e18;

    /// @inheritdoc IAaveLendingAdapter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc IAaveLendingAdapter
    IPoolAddressesProvider public immutable addressesProvider;

    /// @inheritdoc IAaveLendingAdapter
    IPool public immutable pool;

    /// @inheritdoc IAaveLendingAdapter
    address public collateralAsset;

    /// @inheritdoc IAaveLendingAdapter
    address public debtAsset;

    /// @inheritdoc IAaveLendingAdapter
    IERC20 public aToken;

    /// @inheritdoc IAaveLendingAdapter
    IERC20 public variableDebtToken;

    /// @inheritdoc IAaveLendingAdapter
    address public authorizedCreator;

    /// @inheritdoc IAaveLendingAdapter
    bool public isUsed;

    /// @inheritdoc IAaveLendingAdapter
    uint8 public collateralDecimals;

    /// @inheritdoc IAaveLendingAdapter
    uint8 public debtDecimals;

    /// @dev Reverts if the caller is not the stored LeverageManager address
    modifier onlyLeverageManager() {
        if (msg.sender != address(leverageManager)) revert Unauthorized();
        _;
    }

    /// @notice Creates a new AaveLendingAdapter
    /// @param _leverageManager The LeverageManager contract
    /// @param _addressesProvider The Aave v3 PoolAddressesProvider contract
    constructor(ILeverageManager _leverageManager, IPoolAddressesProvider _addressesProvider) {
        leverageManager = _leverageManager;
        addressesProvider = _addressesProvider;
        pool = IPool(_addressesProvider.getPool());
    }

    /// @notice Initializes the AaveLendingAdapter
    /// @param _collateralAsset The address of the collateral asset
    /// @param _debtAsset The address of the debt asset
    /// @param _authorizedCreator The authorized creator of this AaveLendingAdapter
    function initialize(address _collateralAsset, address _debtAsset, address _authorizedCreator)
        external
        initializer
    {
        collateralAsset = _collateralAsset;
        debtAsset = _debtAsset;

        aToken = IERC20(pool.getReserveAToken(_collateralAsset));
        variableDebtToken = IERC20(pool.getReserveVariableDebtToken(_debtAsset));

        collateralDecimals = IERC20Metadata(_collateralAsset).decimals();
        debtDecimals = IERC20Metadata(_debtAsset).decimals();

        authorizedCreator = _authorizedCreator;

        emit AaveLendingAdapterInitialized(_collateralAsset, _debtAsset, _authorizedCreator);
    }

    /// @inheritdoc ILendingAdapter
    function postLeverageTokenCreation(address creator, address) external onlyLeverageManager {
        if (creator != authorizedCreator) revert Unauthorized();
        if (isUsed) revert LendingAdapterAlreadyInUse();
        isUsed = true;

        emit AaveLendingAdapterUsed();
    }

    /// @inheritdoc ILendingAdapter
    function getCollateralAsset() external view returns (IERC20) {
        return IERC20(collateralAsset);
    }

    /// @inheritdoc ILendingAdapter
    function getDebtAsset() external view returns (IERC20) {
        return IERC20(debtAsset);
    }

    /// @inheritdoc ILendingAdapter
    function convertCollateralToDebtAsset(uint256 collateral) public view returns (uint256) {
        IAaveOracle oracle = IAaveOracle(addressesProvider.getPriceOracle());

        uint256 collateralPriceInBase = oracle.getAssetPrice(collateralAsset);
        uint256 debtPriceInBase = oracle.getAssetPrice(debtAsset);

        // Calculate: (collateral * collateralPrice * 10^debtDecimals) / (debtPrice * 10^collateralDecimals)
        // This properly handles decimal differences between assets
        // Rounds down the value of collateral
        // Assumes collateralPriceInBase and debtPriceInBase are in the same base (e.g., 1e8)
        return Math.mulDiv(
            collateral * collateralPriceInBase,
            10 ** debtDecimals,
            debtPriceInBase * (10 ** collateralDecimals),
            Math.Rounding.Floor
        );
    }

    /// @inheritdoc ILendingAdapter
    function convertDebtToCollateralAsset(uint256 debt) public view returns (uint256) {
        IAaveOracle oracle = IAaveOracle(addressesProvider.getPriceOracle());

        uint256 collateralPriceInBase = oracle.getAssetPrice(collateralAsset);
        uint256 debtPriceInBase = oracle.getAssetPrice(debtAsset);

        // Calculate: (debt * debtPrice * 10^collateralDecimals) / (collateralPrice * 10^debtDecimals)
        // Rounds up the value of debt
        // Assumes collateralPriceInBase and debtPriceInBase are in the same base (e.g., 1e8)
        return Math.mulDiv(
            debt * debtPriceInBase,
            10 ** collateralDecimals,
            collateralPriceInBase * (10 ** debtDecimals),
            Math.Rounding.Ceil
        );
    }

    /// @inheritdoc ILendingAdapter
    function getCollateral() public view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    /// @inheritdoc ILendingAdapter
    function getCollateralInDebtAsset() public view returns (uint256) {
        return convertCollateralToDebtAsset(getCollateral());
    }

    /// @inheritdoc ILendingAdapter
    function getDebt() public view returns (uint256) {
        return variableDebtToken.balanceOf(address(this));
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

    /// @inheritdoc IPreLiquidationLendingAdapter
    function getLiquidationPenalty() external view returns (uint256) {
        uint256 liquidationBonus = _getLiquidationBonus();

        // Aave's liquidationBonus is in basis points (e.g., 10500 = 5% bonus = 105%)
        // We need to return the penalty as a WAD value where 1e18 = 100%
        // So 5% penalty = 0.05e18
        if (liquidationBonus <= PERCENTAGE_FACTOR) {
            return 0;
        }
        return Math.mulDiv(liquidationBonus - PERCENTAGE_FACTOR, WAD, PERCENTAGE_FACTOR);
    }

    /// @inheritdoc IAaveLendingAdapter
    function eModeCategory() public view returns (uint8) {
        return uint8(pool.getUserEMode(address(this)));
    }

    /// @dev Returns the liquidation bonus for the collateral asset, accounting for e-mode
    /// @return The liquidation bonus in basis points (e.g., 10500 = 105%)
    function _getLiquidationBonus() internal view returns (uint256) {
        uint8 currentEModeCategory = eModeCategory();

        // If in e-mode, check if collateral is part of the e-mode category
        if (currentEModeCategory != 0) {
            uint16 collateralReserveId = pool.getReserveData(collateralAsset).id;
            uint128 collateralBitmap = pool.getEModeCategoryCollateralBitmap(currentEModeCategory);

            // If collateral is part of e-mode, use e-mode's liquidation bonus
            if ((collateralBitmap >> collateralReserveId) & 1 != 0) {
                DataTypes.CollateralConfig memory eModeConfig =
                    pool.getEModeCategoryCollateralConfig(currentEModeCategory);
                return eModeConfig.liquidationBonus;
            }
        }

        // Otherwise, use the reserve's default liquidation bonus
        DataTypes.ReserveConfigurationMap memory reserveConfig = pool.getConfiguration(collateralAsset);
        return ReserveConfiguration.getLiquidationBonus(reserveConfig);
    }

    /// @inheritdoc ILendingAdapter
    function addCollateral(uint256 amount) external {
        if (amount == 0) return;

        // Transfer the collateral from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(collateralAsset), msg.sender, address(this), amount);

        // Supply the collateral to Aave
        SafeERC20.forceApprove(IERC20(collateralAsset), address(pool), amount);
        pool.supply(collateralAsset, amount, address(this), 0);
    }

    /// @inheritdoc ILendingAdapter
    function removeCollateral(uint256 amount) external onlyLeverageManager {
        if (amount == 0) return;
        // Withdraw the collateral from Aave and send it to msg.sender
        pool.withdraw(collateralAsset, amount, msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function borrow(uint256 amount) external onlyLeverageManager {
        if (amount == 0) return;

        // Borrow the debt asset from Aave and send it to the caller
        pool.borrow(debtAsset, amount, VARIABLE_INTEREST_RATE_MODE, 0, address(this));

        // Transfer the borrowed amount to the caller
        SafeERC20.safeTransfer(IERC20(debtAsset), msg.sender, amount);
    }

    /// @inheritdoc ILendingAdapter
    function repay(uint256 amount) external {
        if (amount == 0) return;

        // Transfer the debt asset from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(debtAsset), msg.sender, address(this), amount);

        // Get current debt to cap repayment. 
        // This is duplication of Aave repay logic, but since it's not part of the interface definition we do it here in case this logic changes in a future Aave update.
        uint256 currentDebt = getDebt();
        uint256 repayAmount = amount > currentDebt ? currentDebt : amount;

        // Repay the debt to Aave
        SafeERC20.forceApprove(IERC20(debtAsset), address(pool), repayAmount);
        pool.repay(debtAsset, repayAmount, VARIABLE_INTEREST_RATE_MODE, address(this));
    }

    /// @inheritdoc IAaveLendingAdapter
    function setEMode(uint8 newEModeCategory) external {
        if (!validateEMode(newEModeCategory)) {
            revert InvalidEMode(newEModeCategory);
        }

        uint8 previousEModeCategory = eModeCategory();

        // Only update if the eMode is different from current
        if (newEModeCategory != previousEModeCategory) {
            pool.setUserEMode(newEModeCategory);
            emit EModeUpdated(previousEModeCategory, newEModeCategory);
        }
    }

    /// @inheritdoc IAaveLendingAdapter
    function validateEMode(uint8 newEModeCategory) public view returns (bool) {
        uint8 currentEModeCategory = eModeCategory();

        // Same category is always valid (no change)
        if (newEModeCategory == currentEModeCategory) {
            return true;
        }

        // Get the config to compare against (either current eMode config or default reserve config)
        DataTypes.CollateralConfig memory currentConfig;
        if (currentEModeCategory != 0) {
            currentConfig = pool.getEModeCategoryCollateralConfig(currentEModeCategory);
        } else {
            currentConfig = _getDefaultReserveConfig();
        }

        // Get the new config to validate (either new eMode config or default reserve config)
        DataTypes.CollateralConfig memory newConfig;
        if (newEModeCategory != 0) {
            // Validate the new eMode category is valid for our assets
            if (!_isEModeValidForAssets(newEModeCategory)) {
                return false;
            }
            newConfig = pool.getEModeCategoryCollateralConfig(newEModeCategory);
        } else {
            newConfig = _getDefaultReserveConfig();
        }

        // New config must have LTV >= current config's LTV (higher LTV is better)
        if (newConfig.ltv < currentConfig.ltv) {
            return false;
        }

        // New config must have liquidationThreshold >= current (higher threshold is better)
        if (newConfig.liquidationThreshold < currentConfig.liquidationThreshold) {
            return false;
        }

        // New config must have liquidationBonus <= current (lower bonus means less penalty, which is better)
        if (newConfig.liquidationBonus > currentConfig.liquidationBonus) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IAaveLendingAdapter
    // TODO: should we have this method at all? If so, should we also have a rescue for all other assets?
    // TODO: if we decide to keep this method it should be a permissioned function
    function rescueForeignCollateral(address asset, address recipient) external returns (uint256 amount) {
        // Cannot rescue the configured collateral asset - use removeCollateral instead
        if (asset == collateralAsset) {
            revert CannotRescueCollateralAsset();
        }

        // Get the aToken for the foreign asset
        address foreignAToken = pool.getReserveAToken(asset);

        // Get the balance of foreign aTokens held by this adapter
        amount = IERC20(foreignAToken).balanceOf(address(this));

        if (amount > 0) {
            // Withdraw the foreign collateral from Aave and send to recipient
            pool.withdraw(asset, amount, recipient);

            emit ForeignCollateralRescued(asset, recipient, amount);
        }

        return amount;
    }

    // ============ Internal Functions ============

    /// @dev Validates that an eMode category is valid for the adapter's collateral and debt assets
    /// @param eModeId The eMode category ID to validate
    /// @return True if the eMode is valid for the assets, false otherwise
    function _isEModeValidForAssets(uint8 eModeId) internal view returns (bool) {
        // Get reserve IDs for collateral and debt assets
        uint16 collateralReserveId = pool.getReserveData(collateralAsset).id;
        uint16 debtReserveId = pool.getReserveData(debtAsset).id;

        // Create bitmasks for checking if assets are in the eMode
        uint128 collateralMask = uint128(1) << collateralReserveId;
        uint128 debtMask = uint128(1) << debtReserveId;

        // Get eMode configuration
        DataTypes.CollateralConfig memory config = pool.getEModeCategoryCollateralConfig(eModeId);

        // Check if this eMode exists (liquidationThreshold != 0)
        if (config.liquidationThreshold == 0) {
            return false;
        }

        // Get the bitmaps for this eMode
        uint128 collateralBitmap = pool.getEModeCategoryCollateralBitmap(eModeId);
        uint128 borrowableBitmap = pool.getEModeCategoryBorrowableBitmap(eModeId);

        // Check if collateral asset is valid collateral in this eMode
        if ((collateralBitmap & collateralMask) == 0) {
            return false;
        }

        // Check if debt asset is borrowable in this eMode
        if ((borrowableBitmap & debtMask) == 0) {
            return false;
        }

        // Check ltvzero bitmap - if collateral is in ltvzero, it can't be used for borrowing power
        uint128 ltvzeroBitmap = pool.getEModeCategoryLtvzeroBitmap(eModeId);
        if ((ltvzeroBitmap & collateralMask) != 0) {
            return false;
        }

        return true;
    }

    /// @dev Gets the default reserve configuration for the collateral asset as a CollateralConfig
    /// @return config The collateral configuration from the reserve's default settings
    function _getDefaultReserveConfig() internal view returns (DataTypes.CollateralConfig memory config) {
        DataTypes.ReserveConfigurationMap memory reserveConfig = pool.getConfiguration(collateralAsset);

        config.ltv = uint16(ReserveConfiguration.getLtv(reserveConfig));
        config.liquidationThreshold = uint16(ReserveConfiguration.getLiquidationThreshold(reserveConfig));
        config.liquidationBonus = uint16(ReserveConfiguration.getLiquidationBonus(reserveConfig));

        return config;
    }
}
