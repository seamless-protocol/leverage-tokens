// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";

contract MorphoLendingAdapterTestUtils is Test {
    function _addCollateral(
        IMorphoLendingAdapter morphoLendingAdapter,
        IERC20 collateralAsset,
        address caller,
        uint256 amount
    ) internal {
        deal(address(collateralAsset), caller, amount);

        vm.startPrank(caller);
        collateralAsset.approve(address(morphoLendingAdapter), amount);
        morphoLendingAdapter.addCollateral(amount);
        vm.stopPrank();
    }

    function _removeCollateral(IMorphoLendingAdapter morphoLendingAdapter, address caller, uint256 amount) internal {
        vm.prank(caller);
        morphoLendingAdapter.removeCollateral(amount);
    }

    function _borrow(IMorphoLendingAdapter morphoLendingAdapter, address caller, uint256 amount) internal {
        vm.prank(caller);
        morphoLendingAdapter.borrow(amount);
    }

    function _repay(IMorphoLendingAdapter morphoLendingAdapter, IERC20 debtAsset, address caller, uint256 amount)
        internal
    {
        deal(address(debtAsset), caller, amount);

        vm.startPrank(caller);
        debtAsset.approve(address(morphoLendingAdapter), amount);
        morphoLendingAdapter.repay(amount);
        vm.stopPrank();
    }
}
