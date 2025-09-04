// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageTokenState, ActionData} from "src/types/DataTypes.sol";

contract LeverageManagerTestBase is Test {
    function _deposit(
        ILeverageManager leverageManager,
        ILeverageToken leverageToken,
        IERC20 collateralAsset,
        address caller,
        uint256 collateralToDeposit,
        uint256 minShares
    ) internal returns (ActionData memory) {
        deal(address(collateralAsset), caller, collateralToDeposit);
        vm.startPrank(caller);
        collateralAsset.approve(address(leverageManager), collateralToDeposit);
        ActionData memory depositData = leverageManager.deposit(leverageToken, collateralToDeposit, minShares);
        vm.stopPrank();

        return depositData;
    }

    function _mint(
        ILeverageManager leverageManager,
        ILeverageToken leverageToken,
        IERC20 collateralAsset,
        address caller,
        uint256 sharesToMint,
        uint256 maxCollateral
    ) internal returns (ActionData memory) {
        deal(address(collateralAsset), caller, maxCollateral);
        vm.startPrank(caller);
        collateralAsset.approve(address(leverageManager), maxCollateral);
        ActionData memory mintData = leverageManager.mint(leverageToken, sharesToMint, maxCollateral);
        vm.stopPrank();

        return mintData;
    }

    function _redeem(
        ILeverageManager leverageManager,
        ILeverageToken leverageToken,
        IERC20 debtAsset,
        address caller,
        uint256 shares,
        uint256 minCollateral,
        uint256 debtToRepay
    ) internal {
        deal(address(debtAsset), caller, debtToRepay);
        vm.startPrank(caller);
        debtAsset.approve(address(leverageManager), debtToRepay);
        leverageManager.redeem(leverageToken, shares, minCollateral);
        vm.stopPrank();
    }

    function _withdraw(
        ILeverageManager leverageManager,
        ILeverageToken leverageToken,
        IERC20 debtAsset,
        address caller,
        uint256 collateral,
        uint256 maxShares,
        uint256 debtToRepay
    ) internal {
        deal(address(debtAsset), caller, debtToRepay);
        vm.startPrank(caller);
        debtAsset.approve(address(leverageManager), debtToRepay);
        leverageManager.withdraw(leverageToken, collateral, maxShares);
        vm.stopPrank();
    }

    function getLeverageTokenState(ILeverageManager leverageManager, ILeverageToken leverageToken)
        internal
        view
        returns (LeverageTokenState memory)
    {
        return LeverageManagerHarness(address(leverageManager)).getLeverageTokenState(leverageToken);
    }
}
