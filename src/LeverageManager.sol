// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILeverageManager} from "./interfaces/ILeverageManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {FeeManager} from "./FeeManager.sol";
import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {LeverageManagerStorage as Storage} from "./storage/LeverageManagerStorage.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LendingLib} from "./library/LendingLib.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TODO: Remove abstract once all functions are implemented
abstract contract LeverageManager is ILeverageManager, FeeManager, UUPSUpgradeable {
    // Base leverage constant, 1e8 = 1x
    uint256 public constant BASE_LEVERAGE = 1e8;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ILeverageManager
    function getStrategyConfig(address strategy) external view returns (Storage.StrategyConfig memory config) {
        return Storage.layout().config[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyCap(address strategy) external view returns (uint256 cap) {
        return Storage.layout().config[strategy].cap;
    }

    /// @inheritdoc ILeverageManager
    function getTotalStrategyShares(address strategy) public view returns (uint256 shares) {
        return Storage.layout().totalShares[strategy];
    }

    /// @inheritdoc ILeverageManager
    function getUserStrategyShares(address strategy, address user) external view returns (uint256 shares) {
        return Storage.layout().userStrategyShares[strategy][user];
    }

    /// @inheritdoc ILeverageManager
    function getStrategyEquityUSD(address strategy) public view returns (uint256 equityUSD) {
        return LendingLib.getStrategyEquityUSD(strategy);
    }

    /// @inheritdoc ILeverageManager
    function deposit(address strategy, uint256 assets, address recipient, uint256 minShares)
        external
        returns (uint256 shares)
    {
        Storage.Layout storage $ = Storage.layout();
        Storage.StrategyConfig storage strategyConfig = $.config[strategy];

        // Cache
        address collateralAsset = $.config[strategy].core.collateral;
        address debtAsset = $.config[strategy].core.debt;

        // Charge deposit fee before checking strategy cap
        uint256 feeAmount = _chargeStrategyFee(strategy, collateralAsset, assets, IFeeManager.Action.Deposit);
        uint256 amountAfterFee = assets - feeAmount;

        // Calculate corresponding amount of debt tokens that should be borrowed and sent to the caller based on target leverage
        uint256 assetsUSD = LendingLib.convertCollateralToUSD(strategyConfig, amountAfterFee);
        uint256 targetLeverage = strategyConfig.leverageConfig.target;
        // Debt is rounded down to user will always receive some wei of debt asset less
        uint256 debtUSD = Math.mulDiv(assetsUSD, targetLeverage - BASE_LEVERAGE, targetLeverage, Math.Rounding.Floor);
        uint256 debtAssets = LendingLib.convertUSDToDebt(strategyConfig, debtUSD);

        // Calculate how much shares user should receive for their equity
        // It is important to calculate shares before supplying and borrowing
        uint256 sharesToMint = _convertToShares(strategy, assetsUSD - debtUSD);

        // Revert if user does not receive enough shares
        if (sharesToMint < minShares) {
            revert InsufficientShares();
        }

        // Take collateral tokens from caller and supply them as collateral on lending pool
        SafeERC20.safeTransferFrom(IERC20(collateralAsset), msg.sender, address(this), assets);
        LendingLib.supply(strategyConfig, amountAfterFee);

        // Borrow debt tokens and send them to recipient
        LendingLib.borrow(strategyConfig, debtAssets);
        SafeERC20.safeTransfer(IERC20(debtAsset), recipient, debtAssets);

        // Give shares to the user and increase total shares in circulation
        $.userStrategyShares[strategy][recipient] += sharesToMint;
        $.totalShares[strategy] += sharesToMint;

        // Emit event and explicit return statement
        emit Deposit(strategy, msg.sender, recipient, assets, sharesToMint);
        return sharesToMint;
    }

    /// @inheritdoc ILeverageManager
    function redeem(address strategy, uint256 shares, address recipient, uint256 minAssets)
        external
        returns (uint256 assets)
    {
        Storage.Layout storage $ = Storage.layout();
        Storage.StrategyConfig storage strategyConfig = $.config[strategy];

        // Cache
        address collateralAsset = $.config[strategy].core.collateral;
        address debtAsset = $.config[strategy].core.debt;
        uint256 totalStrategyShares = getTotalStrategyShares(strategy);

        // Calculate how much collateral assets user should receive, collateral is rounded down
        uint256 totalCollateral = LendingLib.getStrategyCollateral(strategy);
        uint256 userCollateral = Math.mulDiv(totalCollateral, shares, totalStrategyShares, Math.Rounding.Floor);

        // Calculate how much debt assets user should give for debt repay, debt is rounded up
        uint256 totalDebt = LendingLib.getStrategyDebt(strategy);
        uint256 userDebt = Math.mulDiv(totalDebt, shares, totalStrategyShares, Math.Rounding.Ceil);

        // Burn shares from the user and decrease total shares in circulation
        $.userStrategyShares[strategy][msg.sender] -= shares;
        $.totalShares[strategy] -= shares;

        // Takes assets from caller and repays the debt
        SafeERC20.safeTransferFrom(IERC20(debtAsset), msg.sender, address(this), userDebt);
        LendingLib.repay(strategyConfig, userDebt);

        // Withdraw collateral from lending pool, charge withdraw fees on collateral tokens and send assets to recipient
        LendingLib.withdraw(strategyConfig, userCollateral);

        uint256 feeAmount = _chargeStrategyFee(strategy, collateralAsset, userCollateral, IFeeManager.Action.Withdraw);
        uint256 collateralAfterFee = userCollateral - feeAmount;

        // Revert if user does not receive enough assets
        if (userCollateral < minAssets) {
            revert InsufficientAssets();
        }

        SafeERC20.safeTransfer(IERC20(collateralAsset), recipient, collateralAfterFee);

        // Emit event and explicit return statement
        emit Redeem(strategy, msg.sender, recipient, shares, collateralAfterFee);
        return collateralAfterFee;
    }

    /// @notice Function that converts user's equity in USD to strategy shares
    /// @notice Function uses OZ formula for calculating shares
    /// @param strategy Strategy to convert equity to shares for
    /// @param equityUSD Equity to convert to shares
    /// @dev Function must be called before supplying and borrowing
    /// @dev Function should be used to calculate how much shares user should receive for their equity
    function _convertToShares(address strategy, uint256 equityUSD) private view returns (uint256 shares) {
        return Math.mulDiv(
            equityUSD,
            getTotalStrategyShares(strategy) + 10 ** _decimalsOffset(),
            getStrategyEquityUSD(strategy) + 1,
            Math.Rounding.Floor
        );
    }

    function _decimalsOffset() private pure returns (uint256 shares) {
        return 0;
    }
}
