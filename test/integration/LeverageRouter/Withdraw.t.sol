// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouterBase} from "./LeverageRouterBase.t.sol";
import {SwapPathLib} from "test/utils/SwapPathLib.sol";

contract LeverageRouterWithdrawTest is LeverageRouterBase {
    function testFork_withdraw_UniswapV2() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.003150469473258488 ether; // Swap to 3392.292472 USDC requires 1.003150469473258488 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_UniswapV3() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.000932853734567851 ether; // Swap to 3392.292472 USDC requires 1.000932853734567851 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_Aerodrome() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.010346527757605821 ether; // Swap to 3392.292472 USDC requires 1.010346527757605821 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_AerodromeSlipstream() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.00090332288531026 ether; // Swap to 3392.292472 USDC requires 1.000903322885310260 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_UniswapV3_MultiHop() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.001190795778625348 ether; // Swap to 3392.292472 USDC requires 1.001190795778625348 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_Aerodrome_MultiHop() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.023409712556120566 ether; // Swap to 3392.292472 USDC requires 1.023409712556120566 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_AerodromeSlipstream_MultiHop() public {
        uint256 equityInCollateralAsset = _deposit();

        uint256 collateralUsedForDebtSwap = 1.001101865694523417 ether; // Swap to 3392.292472 USDC requires 1.001101865694523417 WETH

        (uint256 collateralToRemove,,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);
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

        _withdrawAndAssertBalances(equityInCollateralAsset, additionalCollateralRequired, swapContext);
    }

    function testFork_withdraw_RevertIf_InsufficientSenderShares() public {
        uint256 equityInCollateralAsset = _deposit();

        // User tries to withdraw more equity than they have
        uint256 equityToWithdraw = equityInCollateralAsset + 1;

        (,, uint256 sharesToBurn,) = leverageManager.previewWithdraw(strategy, equityToWithdraw);

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
        strategy.approve(address(leverageRouter), sharesToBurn);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, user, strategy.balanceOf(user), sharesToBurn
            )
        );
        leverageRouter.withdraw(strategy, equityToWithdraw, sharesToBurn, type(uint256).max, swapContext);
        vm.stopPrank();
    }

    function _deposit() internal returns (uint256 shareValueInCollateralAsset) {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAssetBefore = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC results in 0.997140594716559346 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        uint256 sharesBefore = strategy.balanceOf(user);

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

        _dealAndDeposit(
            WETH,
            USDC,
            userBalanceOfCollateralAssetBefore,
            equityInCollateralAsset,
            additionalCollateralRequired,
            swapContext
        );

        uint256 sharesAfter = strategy.balanceOf(user) - sharesBefore;
        shareValueInCollateralAsset = _convertToAssets(sharesAfter);

        return shareValueInCollateralAsset;
    }

    function _withdrawAndAssertBalances(
        uint256 equityInCollateralAsset,
        uint256 additionalCollateralRequired,
        ISwapAdapter.SwapContext memory swapContext
    ) internal {
        uint256 collateralBeforeWithdraw = morphoLendingAdapter.getCollateral();
        uint256 debtBeforeWithdraw = morphoLendingAdapter.getDebt();
        uint256 userBalanceOfCollateralAssetBeforeWithdraw = WETH.balanceOf(user);

        (uint256 collateralToRemove, uint256 debtToRepay, uint256 sharesToBurn,) =
            leverageManager.previewWithdraw(strategy, equityInCollateralAsset);

        vm.startPrank(user);
        strategy.approve(address(leverageRouter), sharesToBurn);
        leverageRouter.withdraw(
            strategy, equityInCollateralAsset, sharesToBurn, additionalCollateralRequired, swapContext
        );
        vm.stopPrank();

        // Check that the periphery contracts don't hold any assets
        assertEq(WETH.balanceOf(address(swapAdapter)), 0);
        assertEq(USDC.balanceOf(address(swapAdapter)), 0);
        assertEq(WETH.balanceOf(address(leverageRouter)), 0);
        assertEq(USDC.balanceOf(address(leverageRouter)), 0);

        // Collateral and debt are removed from the strategy
        assertEq(morphoLendingAdapter.getCollateral(), collateralBeforeWithdraw - collateralToRemove);
        assertEq(morphoLendingAdapter.getDebt(), debtBeforeWithdraw - debtToRepay);

        // The user receives back the equity, minus the additional collateral required for the swap to repay the flash loan
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAssetBeforeWithdraw + equityInCollateralAsset - additionalCollateralRequired
        );
    }
}
