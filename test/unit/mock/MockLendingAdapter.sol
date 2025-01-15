// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract MockLendingAdapter {
    ERC20Mock public collateralAsset;
    ERC20Mock public debtAsset;

    constructor(address _collateralAsset, address _debtAsset) {
        collateralAsset = ERC20Mock(_collateralAsset);
        debtAsset = ERC20Mock(_debtAsset);
    }

    function addCollateral(address, uint256 amount) external {
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), amount);
    }

    function removeCollateral(address, uint256 amount) external {
        collateralAsset.mint(msg.sender, amount);
    }

    function borrow(address, uint256 amount) external {
        debtAsset.mint(msg.sender, amount);
    }

    function repay(address, uint256 amount) external {
        SafeERC20.safeTransferFrom(debtAsset, msg.sender, address(this), amount);
    }
}
