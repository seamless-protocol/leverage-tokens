// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ActionData} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {SwapPathLib} from "test/utils/SwapPathLib.sol";

contract LeverageRouterRedeemTest is LeverageRouterTest {
    function testFork_redeem_UniswapV2_FullRedeem() public {
        uint256 equityInCollateralAsset = _mint();

        uint256 collateralUsedForDebtSwap = 1.003150469473258488 ether; // Swap to 3392.292472 USDC requires 1.003150469473258488 WETH

        uint256 collateralToRemove = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset).collateral;
        uint256 additionalCollateralRequired =
            equityInCollateralAsset - (collateralToRemove - collateralUsedForDebtSwap);

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_UniswapV2_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _mint();
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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_UniswapV3_FullRedeem() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_UniswapV3_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _mint();
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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_Aerodrome_FullRedeem() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_Aerodrome_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _mint();
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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_AerodromeSlipstream_FullRedeem() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_AerodromeSlipstream_PartialRedeem() public {
        uint256 equityInCollateralAssetMinted = _mint();
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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAssetToRedeem, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_UniswapV3_MultiHop() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_Aerodrome_MultiHop() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_AerodromeSlipstream_MultiHop() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
        });

        _redeemAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_redeem_RevertIf_InsufficientSenderShares() public {
        uint256 equityInCollateralAsset = _mint();

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
            })
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

    function _mint() internal returns (uint256 shareValueInCollateralAsset) {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAssetBefore = 4 ether; // User has more than enough assets for the mint of equity
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC results in 0.997140594716559346 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

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
            })
        });

        _dealAndMint(
            WETH,
            USDC,
            userBalanceOfCollateralAssetBefore,
            equityInCollateralAsset,
            additionalCollateralRequired,
            swapContext
        );

        uint256 sharesAfter = leverageToken.balanceOf(user) - sharesBefore;
        shareValueInCollateralAsset = _convertToAssets(sharesAfter);

        return shareValueInCollateralAsset;
    }

    function _redeemAndAssertBalances(
        uint256 equityInCollateralAsset,
        uint256 additionalCollateralRequired,
        ISwapAdapter.SwapContext memory swapContext
    ) internal {
        uint256 collateralBeforeRedeem = morphoLendingAdapter.getCollateral();
        uint256 debtBeforeRedeem = morphoLendingAdapter.getDebt();
        uint256 userBalanceOfCollateralAssetBeforeRedeem = WETH.balanceOf(user);

        ActionData memory previewData = leverageManager.previewRedeem(leverageToken, equityInCollateralAsset);

        vm.startPrank(user);
        leverageToken.approve(address(leverageRouter), previewData.shares);
        leverageRouter.redeem(
            leverageToken, equityInCollateralAsset, previewData.shares, additionalCollateralRequired, swapContext
        );
        vm.stopPrank();

        // Check that the periphery contracts don't hold any assets
        assertEq(WETH.balanceOf(address(swapAdapter)), 0);
        assertEq(USDC.balanceOf(address(swapAdapter)), 0);
        assertEq(WETH.balanceOf(address(leverageRouter)), 0);
        assertEq(USDC.balanceOf(address(leverageRouter)), 0);

        // Collateral and debt are removed from the leverage token
        assertEq(morphoLendingAdapter.getCollateral(), collateralBeforeRedeem - previewData.collateral);
        assertEq(morphoLendingAdapter.getDebt(), debtBeforeRedeem - previewData.debt);

        // The user receives back the equity, minus the additional collateral required for the swap to repay the flash loan
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAssetBeforeRedeem + equityInCollateralAsset - additionalCollateralRequired
        );
    }
}
