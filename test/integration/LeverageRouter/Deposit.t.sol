// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouterBase} from "./LeverageRouterBase.t.sol";
import {SwapPathLib} from "../../utils/SwapPathLib.sol";

contract LeverageRouterDepositTest is LeverageRouterBase {
    address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV2() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC results in 0.997140594716559346 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

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
            })
        });

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV3() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 0.999899417781964728 ether; // Swap of 3392.292471 USDC results in 0.999899417781964728 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        bytes memory encodedPath = SwapPathLib._encodeUniswapV3Path(path, fees, false);

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

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_Aerodrome() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 0.99780113268167845 ether; // Swap of 3392.292471 USDC results in 0.997801132681678450 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

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

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_AerodromeSlipstream() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 1.00009355883189593 ether; // Swap of 3392.292471 USDC results in 1.000093558831895930 WETH

        uint256 additionalCollateralReceivedFromSwap =
            collateralReceivedFromDebtSwap - (collateralToAdd - equityInCollateralAsset);

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 100;

        bytes memory encodedPath = SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, false);

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

        _dealAndDeposit(WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, 0, swapContext);

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit and the user receives surplus collateral
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - equityInCollateralAsset + additionalCollateralReceivedFromSwap
        );
    }

    function testFork_deposit_UniswapV2_MultiHop() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        // Swap of 3392.292471 USDC results in 0.003436017464761568 WETH (low liquidity on Base Uniswap V2 for the USDC/DAI pair)
        uint256 collateralReceivedFromDebtSwap = 0.003436017464761568 ether;

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(DAI);
        path[2] = address(WETH);

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
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    function testFork_deposit_UniswapV3_MultiHop() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 0.730785046551638276 ether; // Swap of 3392.292471 USDC results in 0.730785046551638276 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(DAI);
        path[2] = address(WETH);

        uint24[] memory fees = new uint24[](2);
        fees[0] = 500;
        fees[1] = 500;

        bytes memory encodedPath = SwapPathLib._encodeUniswapV3Path(path, fees, false);

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

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    function testFork_deposit_Aerodrome_MultiHop() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        // Swap of 3392.292471 USDC results in 0.001479490022113963 WETH (low liquidity on Base Aerodrome for the DAI/WETH pair)
        uint256 collateralReceivedFromDebtSwap = 0.001479490022113963 ether;

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(DAI);
        path[2] = address(WETH);

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

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    function testFork_deposit_AerodromeSlipstream_MultiHop() public {
        uint256 equityInCollateralAsset = 1 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the deposit of equity
        uint256 collateralReceivedFromDebtSwap = 0.999075127525769712 ether; // Swap of 3392.292471 USDC results in 0.999075127525769712 WETH

        // The swap results in less collateral than required to repay the flash loan, so the user needs to approve more collateral than `equityInCollateralAsset`
        uint256 additionalCollateralRequired =
            collateralToAdd - (equityInCollateralAsset + collateralReceivedFromDebtSwap);

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(cbBTC);
        path[2] = address(WETH);

        int24[] memory tickSpacing = new int24[](2);
        tickSpacing[0] = 100;
        tickSpacing[1] = 100;

        bytes memory encodedPath = SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, false);

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

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, equityInCollateralAsset, additionalCollateralRequired, swapContext
        );

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - (equityInCollateralAsset + additionalCollateralRequired)
        );
    }

    function _dealAndDeposit(
        IERC20 collateralAsset,
        IERC20 debtAsset,
        uint256 dealAmount,
        uint256 equityInCollateralAsset,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) internal {
        deal(address(collateralAsset), user, dealAmount);

        vm.startPrank(user);
        collateralAsset.approve(address(leverageRouter), equityInCollateralAsset + maxSwapCostInCollateralAsset);
        leverageRouter.deposit(strategy, equityInCollateralAsset, 0, maxSwapCostInCollateralAsset, swapContext);
        vm.stopPrank();

        // No leftover assets in the LeverageRouter or the SwapAdapter
        assertEq(collateralAsset.balanceOf(address(leverageRouter)), 0);
        assertEq(collateralAsset.balanceOf(address(swapAdapter)), 0);
        assertEq(debtAsset.balanceOf(address(leverageRouter)), 0);
        assertEq(debtAsset.balanceOf(address(swapAdapter)), 0);
    }
}
