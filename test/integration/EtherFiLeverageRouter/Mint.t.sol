// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {EtherFiLeverageRouterTest} from "./EtherFiLeverageRouter.t.sol";
import {SwapPathLib} from "../../utils/SwapPathLib.sol";

contract EtherFiLeverageRouterMintTest is EtherFiLeverageRouterTest {
    function testFork_Mint() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity

        _dealAndMint(WEETH, userBalanceOfCollateralAsset, equityInCollateralAsset);

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
}
