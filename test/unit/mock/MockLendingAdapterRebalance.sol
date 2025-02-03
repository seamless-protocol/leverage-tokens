// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract MockLendingAdapterRebalance {
    uint256 public constant BASE_EXCHANGE_RATE = 1e8;

    ERC20Mock public collateralAsset;
    ERC20Mock public debtAsset;

    uint256 public debt;
    uint256 public collateralToDebtExchangeRate;

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

    function mockCollateral(uint256 amount) external {
        collateralAsset.mint(address(this), amount);
    }

    function mockDebt(uint256 amount) external {
        debt = amount;
    }

    function addCollateral(uint256 amount) external {
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), amount);
    }

    function removeCollateral(uint256 amount) external {
        SafeERC20.safeTransfer(collateralAsset, msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        debtAsset.mint(msg.sender, amount);
        debt += amount;
    }

    function repay(uint256 amount) external {
        debtAsset.burn(msg.sender, amount);
        debt -= amount;
    }

    function setCollateralToDebtExchangeRate(uint256 exchangeRate) external {
        collateralToDebtExchangeRate = exchangeRate;
    }

    function getCollateralInDebtAsset() public view returns (uint256) {
        return collateralAsset.balanceOf(address(this)) * collateralToDebtExchangeRate / BASE_EXCHANGE_RATE;
    }

    function getDebt() public view returns (uint256) {
        return debt;
    }

    function getEquityInDebtAsset() external view returns (uint256) {
        return getCollateralInDebtAsset() - getDebt();
    }

    function convertCollateralToDebtAsset(uint256 collateral) external view returns (uint256) {
        return collateral * collateralToDebtExchangeRate / BASE_EXCHANGE_RATE;
    }
}
