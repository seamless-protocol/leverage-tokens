// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ActionData} from "src/types/DataTypes.sol";
import {EtherFiLeverageRouterTest} from "./EtherFiLeverageRouter.t.sol";

contract EtherFiLeverageRouterMintTest is EtherFiLeverageRouterTest {
    function testFork_Mint() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity

        _dealAndMint(WEETH, userBalanceOfCollateralAsset, equityInCollateralAsset, 0);

        // Initial mint results in 1:1 shares to equity
        assertEq(leverageToken.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the mint
        assertEq(WEETH.balanceOf(user), userBalanceOfCollateralAsset - equityInCollateralAsset);

        assertEq(morphoLendingAdapter.getCollateral(), collateralToAdd);
        // 1.058332450654038384 WETH (WEETH to WETH is not 1:1)
        assertEq(morphoLendingAdapter.getDebt(), 1_058332450654038384);

        // No leftover assets in the LeverageRouter
        assertEq(WEETH.balanceOf(address(leverageRouter)), 0);
        assertEq(WETH.balanceOf(address(leverageRouter)), 0);
        assertEq(address(leverageRouter).balance, 0);
    }

    function testFuzzFork_Mint(uint256 equityInCollateralAsset) public {
        vm.assume(equityInCollateralAsset > 1 ether && equityInCollateralAsset < 500 ether);

        ActionData memory actionData = leverageManager.previewMint(leverageToken, equityInCollateralAsset);

        uint256 expectedWeEthFromDebtSwap =
            etherFiL2ExchangeRateProvider.getConversionAmount(ETH_ADDRESS, actionData.debt);

        uint256 requiredFlashLoan = actionData.collateral - equityInCollateralAsset;
        uint256 additionalCollateralForSwap = requiredFlashLoan - expectedWeEthFromDebtSwap;
        uint256 excessCollateralForSwap = 100;

        _dealAndMint(
            WEETH,
            equityInCollateralAsset + additionalCollateralForSwap + excessCollateralForSwap,
            equityInCollateralAsset,
            additionalCollateralForSwap + excessCollateralForSwap
        );

        assertEq(leverageToken.balanceOf(user), actionData.shares);
        assertEq(WEETH.balanceOf(user), 100); // Excess collateral is returned to the user
    }
}
