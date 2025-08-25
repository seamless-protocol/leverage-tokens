// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ActionData, ActionDataV2} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {SwapPathLib} from "test/utils/SwapPathLib.sol";

import {console2} from "forge-std/console2.sol";

contract LeverageRouterRedeemTest is LeverageRouterTest {
    // 1. preview redemption of shares
    // 2. calculate equity value of shares
    // 3. calculate collateral to flash loan by fetching swap quotes for preview collateral - equity in collateral -> debt asset
    // 4. calculate additional collateral required for the swap of the flash loaned collateral to the required debt if the swap is unfavorable.
    //    in reality, some additional buffer would be added to accommodate for any price impact between off chain and on chain execution
    // 5. calculate min collateral for sender by subtracting the additional collateral required from the equity value of shares
    function testFork_redeem_UniswapV2_FullRedeem() public {
        uint256 shares = _deposit();

        // 1) Preview the redemption of shares
        ActionDataV2 memory previewData = leverageManager.previewRedeemV2(leverageToken, shares);

        // ~3392 USDC required for the redeem
        assertEq(previewData.debt, 3392.292472e6);

        // 2) Calculate the equity / amount of collateral user should receive for their shares
        uint256 equityForSharesInCollateralAsset = (
            shares * leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInCollateralAsset()
        ) / leverageManager.getFeeAdjustedTotalSupply(leverageToken);
        assertEq(equityForSharesInCollateralAsset, 0.999999999879562786 ether);

        // 3) Calculate collateral to flash loan by fetching swap quotes for preview collateral - equity in collateral -> debt asset
        // Collateral to flash loan is the total collateral minus the share value (equity). Some additional collateral is added to account for
        // additional collateral required for the swap of the flash loaned collateral to the required debt
        // Note: The total collateral to flash loan must be <= the previewed collateral on the redeem, otherwise there will always be insufficient
        // collateral after redeeming the shares to repay the flash loan since the full flash loan is swapped to the debt asset.
        // e.g. If we flash loan the full collateral amount (previewData.collateral), the sender will receive no collateral, but probably debt instead.
        uint256 additionalCollateralRequired = 0.0032 ether;
        uint256 collateralToFlashLoan =
            previewData.collateral - equityForSharesInCollateralAsset + additionalCollateralRequired;
        assertEq(collateralToFlashLoan, 1.003200000120437214 ether);

        // The additional collateral required for the swap is taken from the sender's expected collateral / equity to receive from the redeem
        uint256 minCollateralForSender = equityForSharesInCollateralAsset - additionalCollateralRequired;
        assertEq(minCollateralForSender, 0.996799999879562786 ether);

        // The slippage percentage is approx ~0.0032% for the amount of collateral received by the sender
        uint256 slippage = 1e18 - (minCollateralForSender * 1e18 / equityForSharesInCollateralAsset);
        assertEq(slippage, 0.0032000000003854e18);

        // Swap of collateral asset flash loan to debt asset in this block results in ~3392 USDC
        uint256 debtFromSwap = 3392.459885e6;

        // Min debt for sender is the debt from the swap minus the debt required for the redeem
        uint256 minDebtForSender = debtFromSwap - previewData.debt;
        assertEq(minDebtForSender, 0.167413e6);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

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

        _redeemAndAssertBalances(shares, collateralToFlashLoan, minCollateralForSender, minDebtForSender, swapContext);
    }

    function testFork_redeem_UniswapV2_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _deposit();
        uint256 equityInCollateralAssetToRedeem = equityInCollateralAssetMinted / 2;

        uint256 collateralUsedForDebtSwap = 0.501454232794326784 ether; // Swap to 1696.146236 USDC requires 0.501454232794326784 WETH

        uint256 collateralToRemove =
            leverageManager.previewRedeem(leverageToken, equityInCollateralAssetToRedeem).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAssetToRedeem - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

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

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_UniswapV3_FullRedeem() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.000932853734567851 ether; // Swap to 3392.292472 USDC requires 1.000932853734567851 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        bytes memory encodedPath = SwapPathLib._encodeUniswapV3Path(path, fees, true);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            encodedPath: encodedPath,
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: UNISWAP_SWAP_ROUTER02,
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_UniswapV3_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _deposit();
        uint256 equityInCollateralAssetToRedeem = equityInCollateralAssetMinted / 2;

        uint256 collateralUsedForDebtSwap = 0.500462327543122173 ether; // Swap to 1696.146236 USDC requires 0.500462327543122173 WETH

        uint256 collateralToRemove =
            leverageManager.previewRedeem(leverageToken, equityInCollateralAssetToRedeem).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAssetToRedeem - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        bytes memory encodedPath = SwapPathLib._encodeUniswapV3Path(path, fees, true);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            encodedPath: encodedPath,
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: UNISWAP_SWAP_ROUTER02,
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_Aerodrome_FullRedeem() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.010346527757605823 ether; // Swap to 3392.292472 USDC requires 1.010346527757605823 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: AERODROME_ROUTER,
                aerodromePoolFactory: AERODROME_POOL_FACTORY,
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_Aerodrome_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _deposit();
        uint256 equityInCollateralAssetToRedeem = equityInCollateralAssetMinted / 2;

        uint256 collateralUsedForDebtSwap = 0.505102807630211973 ether; // Swap to 1696.146236 USDC requires 0.505102807630211973 WETH

        uint256 collateralToRemove =
            leverageManager.previewRedeem(leverageToken, equityInCollateralAssetToRedeem).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAssetToRedeem - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: AERODROME_ROUTER,
                aerodromePoolFactory: AERODROME_POOL_FACTORY,
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_AerodromeSlipstream_FullRedeem() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.00090332288531026 ether; // Swap to 3392.292472 USDC requires 1.000903322885310260 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 100;

        bytes memory encodedPath = SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, true);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
            encodedPath: encodedPath,
            path: path,
            fees: new uint24[](0),
            tickSpacing: tickSpacing,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: AERODROME_SLIPSTREAM_ROUTER,
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_AerodromeSlipstream_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _deposit();
        uint256 equityInCollateralAssetToRedeem = equityInCollateralAssetMinted / 2;

        uint256 collateralUsedForDebtSwap = 0.500450510128598052 ether; // Swap to 1696.146236 USDC requires 0.500450510128598052 WETH

        uint256 collateralToRemove =
            leverageManager.previewRedeem(leverageToken, equityInCollateralAssetToRedeem).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAssetToRedeem - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 100;

        bytes memory encodedPath = SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, true);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
            encodedPath: encodedPath,
            path: path,
            fees: new uint24[](0),
            tickSpacing: tickSpacing,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: AERODROME_SLIPSTREAM_ROUTER,
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_UniswapV3_MultiHop() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.001190795778625348 ether; // Swap to 3392.292472 USDC requires 1.001190795778625348 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(cbBTC);
        path[2] = address(USDC);

        uint24[] memory fees = new uint24[](2);
        fees[0] = 500;
        fees[1] = 500;

        bytes memory encodedPath = SwapPathLib._encodeUniswapV3Path(path, fees, true);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            encodedPath: encodedPath,
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: UNISWAP_SWAP_ROUTER02,
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_Aerodrome_MultiHop() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.023409712556120568 ether; // Swap to 3392.292472 USDC requires 1.023409712556120568 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(cbBTC);
        path[2] = address(USDC);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: AERODROME_ROUTER,
                aerodromePoolFactory: AERODROME_POOL_FACTORY,
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_AerodromeSlipstream_MultiHop() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.001101865694523417 ether; // Swap to 3392.292472 USDC requires 1.001101865694523417 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(cbBTC);
        path[2] = address(USDC);

        int24[] memory tickSpacing = new int24[](2);
        tickSpacing[0] = 100;
        tickSpacing[1] = 100;

        bytes memory encodedPath = SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, true);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
            encodedPath: encodedPath,
            path: path,
            fees: new uint24[](0),
            tickSpacing: tickSpacing,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: AERODROME_SLIPSTREAM_ROUTER,
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, 0, 0, swapContext);
    }

    function testFork_redeem_RevertIf_InsufficientSenderShares() public {
        uint256 equityInCollateralAsset = _deposit();

        // User tries to redeem more equity than they have
        uint256 equityToRedeem = equityInCollateralAsset + 1;

        uint256 sharesToBurn = leverageManager.previewRedeem(leverageToken, equityToRedeem).shares;

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

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

        vm.startPrank(user);
        leverageToken.approve(address(leverageRouter), sharesToBurn);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, user, leverageToken.balanceOf(user), sharesToBurn
            )
        );
        leverageRouter.redeem(leverageToken, equityToRedeem, sharesToBurn, type(uint256).max, swapContext);
        vm.stopPrank();
    }

    function _deposit() internal returns (uint256 shares) {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392.292471e6;
        uint256 userBalanceOfCollateralAssetBefore = 4 ether; // User has more than enough assets for the mint of equity
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC results in 0.997140594716559346 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired = collateralToAdd - (collateralFromSender + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        uint256 sharesBefore = leverageToken.balanceOf(user);

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
            WETH,
            USDC,
            userBalanceOfCollateralAssetBefore,
            collateralFromSender + additionalCollateralRequired,
            debt,
            0,
            swapContext
        );

        uint256 sharesAfter = leverageToken.balanceOf(user) - sharesBefore;

        return sharesAfter;
    }

    function _redeemAndAssertBalances(
        uint256 shares,
        uint256 collateralFlashLoanAmount,
        uint256 minCollateralForSender,
        uint256 minDebtForSender,
        ISwapAdapter.SwapContext memory swapContext
    ) internal {
        uint256 collateralBeforeRedeem = morphoLendingAdapter.getCollateral();
        uint256 debtBeforeRedeem = morphoLendingAdapter.getDebt();
        uint256 userBalanceOfCollateralAssetBeforeRedeem = WETH.balanceOf(user);
        uint256 userBalanceOfDebtAssetBeforeRedeem = USDC.balanceOf(user);

        ActionDataV2 memory previewData = leverageManager.previewRedeemV2(leverageToken, shares);

        vm.startPrank(user);
        leverageToken.approve(address(leverageRouter), shares);
        leverageRouter.redeemV2(leverageToken, shares, collateralFlashLoanAmount, minCollateralForSender, swapContext);
        vm.stopPrank();

        // Check that the periphery contracts don't hold any assets
        assertEq(WETH.balanceOf(address(swapAdapter)), 0);
        assertEq(USDC.balanceOf(address(swapAdapter)), 0);
        assertEq(WETH.balanceOf(address(leverageRouter)), 0);
        assertEq(USDC.balanceOf(address(leverageRouter)), 0);

        // Collateral and debt are removed from the leverage token
        assertEq(morphoLendingAdapter.getCollateral(), collateralBeforeRedeem - previewData.collateral);
        assertEq(morphoLendingAdapter.getDebt(), debtBeforeRedeem - previewData.debt);

        // The user receives back at least the min collateral and debt
        assertGe(WETH.balanceOf(user), userBalanceOfCollateralAssetBeforeRedeem + minCollateralForSender);
        assertGe(USDC.balanceOf(user), userBalanceOfDebtAssetBeforeRedeem + minDebtForSender);
    }
}
