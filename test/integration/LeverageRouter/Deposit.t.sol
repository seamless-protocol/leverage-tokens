// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
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
        // We add 1 to offset precision differences between LM.previewDeposit (used by LM.deposit) and LM.convertDebtToCollateral.
        // convertDebtToCollateral rounds up, previewDeposit rounds down when calculating debt from shares, and shares is calculated
        // from collateral, also rounded down.
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + 1;
        assertEq(collateralRequired, 1.994281188504426822 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // More than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.997140594252213411 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.994290732650270211 ether;
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
        assertEq(remainingCollateral, 0.000009544145843389 ether);

        assertEq(WETH.balanceOf(user), userBalanceOfCollateralAsset - collateralFromSender + remainingCollateral);
        assertEq(
            WETH.balanceOf(user), userBalanceOfCollateralAsset - (collateralRequired - collateralReceivedFromDebtSwap)
        );

        assertGe(leverageToken.balanceOf(user), minShares);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
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
        // We add 1 to offset precision differences between LM.previewDeposit (used by LM.deposit) and LM.convertDebtToCollateral.
        // convertDebtToCollateral rounds up, previewDeposit rounds down when calculating debt from shares, and shares is calculated
        // from collateral, also rounded down.
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + 1;
        assertEq(collateralRequired, 1.994281188504426822 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // Less than minShares (0.01% slippage) will be minted
            assertLt(previewData.shares, minShares);
            assertEq(previewData.shares, 0.997140594252213411 ether);

            // The slippage is greater than 0.01%
            uint256 actualSlippage = 1e18 - previewData.shares * 1e18 / sharesFromDeposit;
            assertEq(actualSlippage, 0.002859405747786589e18); // ~0.286% slippage

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.994290732650270211 ether;
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
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, 0.997140594252213411 ether, 0.99715 ether)
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, debtReduced, minShares, swapContext);
        vm.stopPrank();
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV2_InsufficientCollateralForDeposit() public {
        uint256 collateralFromSender = 0.01 ether;

        uint256 collateralFromSenderInDebt = morphoLendingAdapter.convertCollateralToDebtAsset(collateralFromSender);
        assertEq(collateralFromSenderInDebt, 33.922924e6);
        // Slightly less when converting back to collateral due to precision loss
        assertEq(
            morphoLendingAdapter.convertDebtToCollateralAsset(collateralFromSenderInDebt), 0.009999999788958522 ether
        );

        // 2x collateral ratio
        ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
        assertEq(previewData.collateral, collateralFromSender * 2);
        assertEq(previewData.debt, collateralFromSenderInDebt);

        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, previewData.debt, Math.Rounding.Ceil) + 1;
        assertEq(collateralRequired, 0.019999999577917045 ether);

        // Preview again using the new collateral required; results in the same debt amount
        assertEq(leverageManager.previewDeposit(leverageToken, collateralRequired).debt, previewData.debt);

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

        // The collateral received from swapping 33.922924e6 USDC is 0.009976155542446272 WETH in this block using Uniswap V2
        uint256 collateralReceivedFromDebtSwap = 0.009976155542446272 ether;

        // The collateral from the swap + the collateral from the sender is less than the collateral required
        uint256 totalCollateral = collateralReceivedFromDebtSwap + collateralFromSender;
        assertLt(totalCollateral, collateralRequired);

        deal(address(WETH), user, collateralFromSender);
        vm.startPrank(user);
        WETH.approve(address(leverageRouter), collateralFromSender);

        // Reverts due to insufficient collateral from swap + user for the deposit
        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageRouter.InsufficientCollateralForDeposit.selector, totalCollateral, collateralRequired
            )
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, previewData.debt, 0, swapContext);
        vm.stopPrank();

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage =
            collateralReceivedFromDebtSwap * 1e18 / (collateralFromSender * 2 - collateralFromSender);
        assertEq(deltaPercentage, 0.9976155542446272e18);
        uint256 debtReduced = previewData.debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 33.842036e6);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + 1;
        assertEq(collateralRequired, 0.019952310293648432 ether);

        // Sanity check: preview again using the new collateral required. This is used by the LM deposit logic
        previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
        assertEq(previewData.debt, debtReduced);

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debtReduced, 0, swapContext);
    }

    function testFuzzFork_deposit_UniswapV2_ExceedsSlippage(uint256 collateralFromSender) public {
        rebalanceAdapter = _deployRebalanceAdapter(1.5e18, 2e18, 2.5e18, 7 minutes, 1.2e18, 0.9e18, 1.2e18, 40_00);

        leverageToken = leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(morphoLendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(address(rebalanceAdapter)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            "Seamless ETH/USDC 2x leverage token",
            "ltETH/USDC-2x"
        );
    }
}
