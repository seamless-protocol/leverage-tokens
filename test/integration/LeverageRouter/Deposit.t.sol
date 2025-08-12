// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ActionDataV2} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {SwapPathLib} from "../../utils/SwapPathLib.sol";

import {console2} from "forge-std/console2.sol";

contract LeverageRouterDepositTest is LeverageRouterTest {
    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV2() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 sharesFromDeposit = 1 ether;
        uint256 minShares = sharesFromDeposit * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC results in 0.997140594716559346 WETH

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, sharesFromDeposit);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.997140594716559346e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3382_592531);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);
        assertEq(collateralRequired, 1.994281188504426821 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            // Results in 1 less than required for the flash loaned debt amount, since previewDeposit converts collateral
            // to shares using Math.Rounding.Floor, then uses that share amount to get the debt which is also rounded down.
            // convertDebtToCollateral only rounds up once.
            assertEq(previewData.debt, debtReduced - 1);

            // More than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.99714059425221341 ether);

            // Thus, we reduce the debt amount to flash loan by that 1 to ensure there is enough collateral for the deposit.
            // In practice, integrators would probably add some additional buffer here to account for price slippage between
            // off-chain and on-chain execution
            debtReduced = debtReduced - 1;

            // LR.deposit will use the collateral required for the reduced debt amount
            collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);
            assertEq(collateralRequired, 1.994281187914855014 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.994290732356467777 ether;
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, collateralFromSender, debtReduced, minShares, swapContext
        );

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user
        uint256 remainingCollateral = collateralFromSender - (collateralRequired - collateralReceivedFromDebtSwap);
        assertEq(remainingCollateral, 0.000009544441612763 ether);
        assertEq(WETH.balanceOf(user), userBalanceOfCollateralAsset - collateralFromSender + remainingCollateral);
        assertEq(
            WETH.balanceOf(user), userBalanceOfCollateralAsset - (collateralRequired - collateralReceivedFromDebtSwap)
        );

        assertGe(leverageToken.balanceOf(user), minShares);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    function testFork_deposit_UniswapV2_ExceedsSlippage() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 sharesFromDeposit = 1 ether;
        uint256 minShares = sharesFromDeposit * 0.99715e18 / 1e18; // 0.285% slippage
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC results in 0.997140594716559346 WETH

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, sharesFromDeposit);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.997140594716559346e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3382_592531);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);
        assertEq(collateralRequired, 1.994281188504426821 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            // Results in 1 less than required for the flash loaned debt amount, since previewDeposit converts collateral
            // to shares using Math.Rounding.Floor, then uses that share amount to get the debt which is also rounded down.
            // convertDebtToCollateral only rounds up once.
            assertEq(previewData.debt, debtReduced - 1);

            // Less than minShares (0.01% slippage) will be minted
            assertLt(previewData.shares, minShares);
            assertEq(previewData.shares, 0.99714059425221341 ether);

            // The slippage is greater than 0.01%
            uint256 actualSlippage = 1e18 - previewData.shares * 1e18 / sharesFromDeposit;
            assertEq(actualSlippage, 0.00285940574778659e18); // ~0.286% slippage

            // Thus, we reduce the debt amount to flash loan by that 1 to ensure there is enough collateral for the deposit.
            // In practice, integrators would probably add some additional buffer here to account for price slippage between
            // off-chain and on-chain execution
            debtReduced = debtReduced - 1;

            // LR.deposit will use the collateral required for the reduced debt amount
            collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);
            assertEq(collateralRequired, 1.994281187914855014 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.994290732356467777 ether;
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        deal(address(WETH), user, userBalanceOfCollateralAsset);
        vm.startPrank(user);
        WETH.approve(address(leverageRouter), collateralFromSender);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, 0.997140593957427507 ether, 0.99715 ether)
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, debtReduced, minShares, swapContext);
        vm.stopPrank();
    }
}
