// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouterBase} from "./LeverageRouterBase.t.sol";
import {SwapPathLib} from "../../utils/SwapPathLib.sol";

contract LeverageRouterDepositTest is LeverageRouterBase {
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_SLIPSTREAM_ROUTER = 0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5;
    address public constant AERODROME_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant UNISWAP_V2_ROUTER02 = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address public constant UNISWAP_SWAP_ROUTER02 = 0x2626664c2603336E57B271c5C0b26F421741e481;

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

        deal(address(WETH), user, userBalanceOfCollateralAsset);

        vm.startPrank(user);
        WETH.approve(address(leverageRouter), equityInCollateralAsset + additionalCollateralRequired);
        leverageRouter.deposit(strategy, equityInCollateralAsset, 0, additionalCollateralRequired, swapContext);
        vm.stopPrank();

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

        deal(address(WETH), user, userBalanceOfCollateralAsset);

        vm.startPrank(user);
        WETH.approve(address(leverageRouter), equityInCollateralAsset + additionalCollateralRequired);
        leverageRouter.deposit(strategy, equityInCollateralAsset, 0, additionalCollateralRequired, swapContext);
        vm.stopPrank();

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

        deal(address(WETH), user, userBalanceOfCollateralAsset);

        vm.startPrank(user);
        WETH.approve(address(leverageRouter), equityInCollateralAsset + additionalCollateralRequired);
        leverageRouter.deposit(strategy, equityInCollateralAsset, 0, additionalCollateralRequired, swapContext);
        vm.stopPrank();

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

        deal(address(WETH), user, userBalanceOfCollateralAsset);

        vm.startPrank(user);
        WETH.approve(address(leverageRouter), equityInCollateralAsset);
        leverageRouter.deposit(strategy, equityInCollateralAsset, 0, 0, swapContext);
        vm.stopPrank();

        // Initial deposit results in 1:1 shares to equity
        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        // Collateral is taken from the user for the deposit and the user receives surplus collateral
        assertEq(
            WETH.balanceOf(user),
            userBalanceOfCollateralAsset - equityInCollateralAsset + additionalCollateralReceivedFromSwap
        );
    }
}
