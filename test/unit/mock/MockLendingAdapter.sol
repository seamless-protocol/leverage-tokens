// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract MockLendingAdapter {
    IERC20 public collateralAsset;
    ERC20Mock public debtAsset;

    constructor(address _collateralAsset, address _debtAsset) {
        collateralAsset = IERC20(_collateralAsset);
        debtAsset = ERC20Mock(_debtAsset);
    }

    function addCollateral(uint256, uint256 amount) external {
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), amount);
    }

    function borrow(uint256, uint256 amount) external {
        debtAsset.mint(msg.sender, amount);
    }
}
