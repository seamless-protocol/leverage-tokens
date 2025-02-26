// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {IAerodromeRouter} from "../interfaces/periphery/IAerodromeRouter.sol";
import {IAerodromeSlipstreamRouter} from "../interfaces/periphery/IAerodromeSlipstreamRouter.sol";
import {IUniswapSwapRouter02} from "../interfaces/periphery/IUniswapSwapRouter02.sol";
import {ISwapAdapter} from "../interfaces/periphery/ISwapAdapter.sol";

contract SwapAdapter is ISwapAdapter, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function initialize(address initialAdmin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ISwapAdapter
    function swapExactInput(
        IERC20 inputToken,
        uint256 inputAmount,
        uint256 minOutputAmount,
        SwapContext memory swapContext
    ) external returns (uint256) {
        SafeERC20.safeTransferFrom(inputToken, msg.sender, address(this), inputAmount);

        uint256 outputAmount = 0;
        if (swapContext.exchange == Exchange.AERODROME) {
            outputAmount = _swapExactInputAerodrome(inputAmount, minOutputAmount, swapContext);
        } else if (swapContext.exchange == Exchange.AERODROME_SLIPSTREAM) {
            outputAmount = _swapExactInputAerodromeSlipstream(inputAmount, minOutputAmount, swapContext);
        } else if (swapContext.exchange == Exchange.UNISWAP_V2) {
            outputAmount = _swapExactInputUniV2(inputAmount, minOutputAmount, swapContext);
        } else if (swapContext.exchange == Exchange.UNISWAP_V3) {
            outputAmount = _swapExactInputUniV3(inputAmount, minOutputAmount, swapContext);
        }

        return outputAmount;
    }

    function _swapAerodrome(
        uint256 inputAmount,
        uint256 minOutputAmount,
        address receiver,
        address aerodromeRouter,
        address aerodromeFactory,
        address[] memory path
    ) internal returns (uint256 outputAmount) {
        IAerodromeRouter.Route[] memory routes = _generateAerodromeRoutes(path, aerodromeFactory);

        IERC20(path[0]).approve(aerodromeRouter, inputAmount);
        return IAerodromeRouter(aerodromeRouter).swapExactTokensForTokens(
            inputAmount, minOutputAmount, routes, receiver, block.timestamp
        )[1];
    }

    function _swapExactInputAerodrome(uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
        internal
        returns (uint256 outputAmount)
    {
        return _swapAerodrome(
            inputAmount,
            minOutputAmount,
            msg.sender,
            swapContext.exchangeAddresses.aerodromeRouter,
            swapContext.exchangeAddresses.aerodromeFactory,
            swapContext.path
        );
    }

    function _swapExactInputAerodromeSlipstream(
        uint256 inputAmount,
        uint256 minOutputAmount,
        SwapContext memory swapContext
    ) internal returns (uint256 outputAmount) {
        // Check that the number of routes is equal to the number of tick spacings plus one, as required by Aerodrome Slipstream
        if (swapContext.path.length != swapContext.tickSpacing.length + 1) revert InvalidNumTicks();

        IAerodromeSlipstreamRouter aerodromeSlipstreamRouter =
            IAerodromeSlipstreamRouter(swapContext.exchangeAddresses.aerodromeSlipstreamRouter);

        IERC20(swapContext.path[0]).approve(address(aerodromeSlipstreamRouter), inputAmount);

        if (swapContext.path.length == 2) {
            IAerodromeSlipstreamRouter.ExactInputSingleParams memory swapParams = IAerodromeSlipstreamRouter
                .ExactInputSingleParams({
                tokenIn: swapContext.path[0],
                tokenOut: swapContext.path[1],
                tickSpacing: swapContext.tickSpacing[0],
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: inputAmount,
                amountOutMinimum: minOutputAmount,
                sqrtPriceLimitX96: 0
            });

            return aerodromeSlipstreamRouter.exactInputSingle(swapParams);
        } else {
            IAerodromeSlipstreamRouter.ExactInputParams memory swapParams = IAerodromeSlipstreamRouter.ExactInputParams({
                path: swapContext.encodedPath,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: inputAmount,
                amountOutMinimum: minOutputAmount
            });

            return aerodromeSlipstreamRouter.exactInput(swapParams);
        }
    }

    function _swapExactInputUniV2(uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
        internal
        returns (uint256 outputAmount)
    {
        IUniswapSwapRouter02 uniswapRouter02 = IUniswapSwapRouter02(swapContext.exchangeAddresses.uniswapRouter02);

        IERC20(swapContext.path[0]).approve(address(uniswapRouter02), inputAmount);
        return uniswapRouter02.swapExactTokensForTokens(inputAmount, minOutputAmount, swapContext.path, msg.sender);
    }

    function _swapExactInputUniV3(uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
        internal
        returns (uint256 outputAmount)
    {
        // Check that the number of fees is equal to the number of paths minus one, as required by Uniswap V3
        if (swapContext.path.length != swapContext.fees.length + 1) revert InvalidNumFees();

        IUniswapSwapRouter02 uniswapRouter02 = IUniswapSwapRouter02(swapContext.exchangeAddresses.uniswapRouter02);

        IERC20(swapContext.path[0]).approve(address(uniswapRouter02), inputAmount);

        if (swapContext.path.length == 2) {
            IUniswapSwapRouter02.ExactInputSingleParams memory params = IUniswapSwapRouter02.ExactInputSingleParams({
                tokenIn: swapContext.path[0],
                tokenOut: swapContext.path[1],
                fee: swapContext.fees[0],
                recipient: msg.sender,
                amountIn: inputAmount,
                amountOutMinimum: minOutputAmount,
                sqrtPriceLimitX96: 0
            });

            return uniswapRouter02.exactInputSingle(params);
        } else {
            IUniswapSwapRouter02.ExactInputParams memory params = IUniswapSwapRouter02.ExactInputParams({
                path: swapContext.encodedPath,
                recipient: msg.sender,
                amountIn: inputAmount,
                amountOutMinimum: minOutputAmount
            });

            return uniswapRouter02.exactInput(params);
        }
    }

    /// @notice Generate the array of Routes as required by the Aerodrome router
    function _generateAerodromeRoutes(address[] memory path, address aerodromeFactory)
        internal
        pure
        returns (IAerodromeRouter.Route[] memory routes)
    {
        routes = new IAerodromeRouter.Route[](path.length - 1);
        for (uint256 i = 0; i < path.length - 1; i++) {
            routes[i] = IAerodromeRouter.Route(path[i], path[i + 1], false, aerodromeFactory);
        }
    }
}
