// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract MockLendingAdapter {
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e4;

    ERC20Mock public collateralAsset;
    ERC20Mock public debtAsset;

    uint256 public collateralToDebtAssetExchangeRate;
    uint256 public debtAssetToCollateralExchangeRate;

    constructor(address _collateralAsset, address _debtAsset) {
        collateralAsset = ERC20Mock(_collateralAsset);
        debtAsset = ERC20Mock(_debtAsset);
    }

    function getCollateralAsset() external view returns (IERC20) {
        return collateralAsset;
    }

    function getDebtAsset() external view returns (IERC20) {
        return debtAsset;
    }

    function convertCollateralToDebtAsset(uint256 amount) external view returns (uint256) {
        return collateralToDebtAssetExchangeRate > 0
            ? Math.mulDiv(amount, collateralToDebtAssetExchangeRate, EXCHANGE_RATE_PRECISION, Math.Rounding.Floor)
            : amount;
    }

    function convertDebtToCollateralAsset(uint256 amount) external view returns (uint256) {
        return collateralToDebtAssetExchangeRate > 0
            ? Math.mulDiv(amount, EXCHANGE_RATE_PRECISION, collateralToDebtAssetExchangeRate, Math.Rounding.Ceil)
            : amount;
    }

    function addCollateral(uint256 amount) external {
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), amount);
    }

    function removeCollateral(uint256 amount) external {
        collateralAsset.mint(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        debtAsset.mint(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        SafeERC20.safeTransferFrom(debtAsset, msg.sender, address(this), amount);
    }

    function mockConvertCollateralToDebtAssetExchangeRate(uint256 exchangeRate) external {
        collateralToDebtAssetExchangeRate = exchangeRate;
    }

    function mockConvertDebtAssetToCollateralExchangeRate(uint256 exchangeRate) external {
        debtAssetToCollateralExchangeRate = exchangeRate;
    }
}
