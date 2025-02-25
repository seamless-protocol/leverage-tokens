// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {IAerodromeRouter} from "../interfaces/IAerodromeRouter.sol";
import {IAerodromeSlipstreamRouter} from "../interfaces/IAerodromeSlipstreamRouter.sol";
import {IUniswapSwapRouter02} from "../interfaces/IUniswapSwapRouter02.sol";
import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";

contract SwapAdapter is ISwapAdapter, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function initialize(address initialAdmin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ISwapAdapter
    function swapExactFromToMinTo(
        IERC20 fromToken,
        uint256 fromAmount,
        uint256 minToAmount,
        SwapContext memory swapContext
    ) external returns (uint256) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), fromAmount);

        uint256 toAmount = 0;
        if (swapContext.exchange == Exchange.AERODROME) {
            toAmount = _swapExactFromToMinToAerodrome(fromAmount, minToAmount, swapContext);
        } else if (swapContext.exchange == Exchange.AERODROME_SLIPSTREAM) {
            toAmount = _swapExactFromToMinToAerodromeSlipstream(fromAmount, minToAmount, swapContext);
        } else if (swapContext.exchange == Exchange.UNISWAP_V2) {
            toAmount = _swapExactFromToMinToUniV2(fromAmount, minToAmount, swapContext);
        } else if (swapContext.exchange == Exchange.UNISWAP_V3) {
            toAmount = _swapExactFromToMinToUniV3(fromAmount, minToAmount, swapContext);
        }

        return toAmount;
    }

    /// @inheritdoc ISwapAdapter
    function swapMaxFromToExactTo(
        IERC20 fromToken,
        uint256 toAmount,
        uint256 maxFromAmount,
        SwapContext memory swapContext
    ) external returns (uint256) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), maxFromAmount);

        uint256 fromAmount = 0;
        if (swapContext.exchange == Exchange.AERODROME) {
            fromAmount = _swapMaxFromToExactToAerodrome(toAmount, maxFromAmount, swapContext);
        } else if (swapContext.exchange == Exchange.AERODROME_SLIPSTREAM) {
            fromAmount = _swapMaxFromToExactToAerodromeSlipstream(toAmount, maxFromAmount, swapContext);
        } else if (swapContext.exchange == Exchange.UNISWAP_V3) {
            fromAmount = _swapMaxFromToExactToUniV3(toAmount, maxFromAmount, swapContext);
        } else if (swapContext.exchange == Exchange.UNISWAP_V2) {
            fromAmount = _swapMaxFromToExactToUniV2(toAmount, maxFromAmount, swapContext);
        }

        return fromAmount;
    }

    function _swapAerodrome(
        uint256 fromAmount,
        uint256 minToAmount,
        address receiver,
        address aerodromeRouter,
        address aerodromeFactory,
        address[] memory path
    ) internal returns (uint256 toAmount) {
        IAerodromeRouter.Route[] memory routes = _generateAerodromeRoutes(path, aerodromeFactory);

        IERC20(path[0]).approve(aerodromeRouter, fromAmount);
        return IAerodromeRouter(aerodromeRouter).swapExactTokensForTokens(
            fromAmount, minToAmount, routes, receiver, block.timestamp
        )[1];
    }

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

    function _swapExactFromToMinToAerodrome(uint256 fromAmount, uint256 minToAmount, SwapContext memory swapContext)
        internal
        returns (uint256 toAmount)
    {
        return _swapAerodrome(
            fromAmount,
            minToAmount,
            msg.sender,
            swapContext.exchangeAddresses.aerodromeRouter,
            swapContext.exchangeAddresses.aerodromeFactory,
            swapContext.path
        );
    }

    function _swapExactFromToMinToAerodromeSlipstream(
        uint256 fromAmount,
        uint256 minToAmount,
        SwapContext memory swapContext
    ) internal returns (uint256 toAmount) {
        // Check that the number of routes is equal to the number of tick spacings plus one, as required by Aerodrome Slipstream
        if (swapContext.path.length != swapContext.tickSpacing.length + 1) revert InvalidNumTicks();

        IAerodromeSlipstreamRouter aerodromeSlipstreamRouter =
            IAerodromeSlipstreamRouter(swapContext.exchangeAddresses.aerodromeSlipstreamRouter);

        IERC20(swapContext.path[0]).approve(address(aerodromeSlipstreamRouter), fromAmount);

        if (swapContext.path.length == 2) {
            IAerodromeSlipstreamRouter.ExactInputSingleParams memory swapParams = IAerodromeSlipstreamRouter
                .ExactInputSingleParams({
                tokenIn: swapContext.path[0],
                tokenOut: swapContext.path[1],
                tickSpacing: swapContext.tickSpacing[0],
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: fromAmount,
                amountOutMinimum: minToAmount,
                sqrtPriceLimitX96: 0
            });

            return aerodromeSlipstreamRouter.exactInputSingle(swapParams);
        } else {
            IAerodromeSlipstreamRouter.ExactInputParams memory swapParams = IAerodromeSlipstreamRouter.ExactInputParams({
                path: _encodeAerodromeSlipstreamPath(swapContext.path, swapContext.tickSpacing, false),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: fromAmount,
                amountOutMinimum: minToAmount
            });

            return aerodromeSlipstreamRouter.exactInput(swapParams);
        }
    }

    function _swapExactFromToMinToUniV2(uint256 fromAmount, uint256 minToAmount, SwapContext memory swapContext)
        internal
        returns (uint256 toAmount)
    {
        IUniswapSwapRouter02 uniswapRouter02 = IUniswapSwapRouter02(swapContext.exchangeAddresses.uniswapRouter02);

        IERC20(swapContext.path[0]).approve(address(uniswapRouter02), fromAmount);
        return uniswapRouter02.swapExactTokensForTokens(fromAmount, minToAmount, swapContext.path, msg.sender);
    }

    function _swapExactFromToMinToUniV3(uint256 fromAmount, uint256 minToAmount, SwapContext memory swapContext)
        internal
        returns (uint256 toAmount)
    {
        if (swapContext.path.length != swapContext.fees.length + 1) revert InvalidNumFees();

        IUniswapSwapRouter02 uniswapRouter02 = IUniswapSwapRouter02(swapContext.exchangeAddresses.uniswapRouter02);

        IERC20(swapContext.path[0]).approve(address(uniswapRouter02), fromAmount);

        if (swapContext.path.length == 2) {
            IUniswapSwapRouter02.ExactInputSingleParams memory params = IUniswapSwapRouter02.ExactInputSingleParams({
                tokenIn: swapContext.path[0],
                tokenOut: swapContext.path[1],
                fee: swapContext.fees[0],
                recipient: msg.sender,
                amountIn: fromAmount,
                amountOutMinimum: minToAmount,
                sqrtPriceLimitX96: 0
            });

            return uniswapRouter02.exactInputSingle(params);
        } else {
            IUniswapSwapRouter02.ExactInputParams memory params = IUniswapSwapRouter02.ExactInputParams({
                path: _encodeUniswapV3Path(swapContext.path, swapContext.fees, false),
                recipient: msg.sender,
                amountIn: fromAmount,
                amountOutMinimum: minToAmount
            });

            return uniswapRouter02.exactInput(params);
        }
    }

    function _swapMaxFromToExactToAerodrome(uint256 toAmount, uint256 maxFromAmount, SwapContext memory swapContext)
        internal
        returns (uint256 fromAmount)
    {
        uint256 toAmountReceived = _swapAerodrome(
            maxFromAmount,
            toAmount,
            address(this),
            swapContext.exchangeAddresses.aerodromeRouter,
            swapContext.exchangeAddresses.aerodromeFactory,
            swapContext.path
        );

        // We only need toAmount of the received tokens, so we swap the surplus back to the fromToken and send it back to sender
        if (toAmountReceived > toAmount) {
            uint256 surplusFromAmount = _swapAerodrome(
                toAmountReceived - toAmount,
                0,
                address(this),
                swapContext.exchangeAddresses.aerodromeRouter,
                swapContext.exchangeAddresses.aerodromeFactory,
                _reversePath(swapContext.path)
            );

            // We need to transfer the toToken and the surplus fromToken to the sender
            SafeERC20.safeTransfer(IERC20(swapContext.path[0]), msg.sender, surplusFromAmount);
            SafeERC20.safeTransfer(IERC20(swapContext.path[swapContext.path.length - 1]), msg.sender, toAmount);

            return maxFromAmount - surplusFromAmount;
        } else {
            SafeERC20.safeTransfer(IERC20(swapContext.path[swapContext.path.length - 1]), msg.sender, toAmount);

            return maxFromAmount;
        }
    }

    function _swapMaxFromToExactToAerodromeSlipstream(
        uint256 toAmount,
        uint256 maxFromAmount,
        SwapContext memory swapContext
    ) internal returns (uint256 fromAmount) {
        // Check that the number of routes is equal to the number of tick spacings plus one, as required by Aerodrome Slipstream
        if (swapContext.path.length != swapContext.tickSpacing.length + 1) revert InvalidNumTicks();

        IAerodromeSlipstreamRouter aerodromeSlipstreamRouter =
            IAerodromeSlipstreamRouter(swapContext.exchangeAddresses.aerodromeSlipstreamRouter);

        IERC20(swapContext.path[0]).approve(address(aerodromeSlipstreamRouter), maxFromAmount);

        if (swapContext.path.length == 2) {
            IAerodromeSlipstreamRouter.ExactOutputSingleParams memory swapParams = IAerodromeSlipstreamRouter
                .ExactOutputSingleParams({
                tokenIn: swapContext.path[0],
                tokenOut: swapContext.path[1],
                tickSpacing: swapContext.tickSpacing[0],
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: toAmount,
                amountInMaximum: maxFromAmount,
                sqrtPriceLimitX96: 0
            });
            return aerodromeSlipstreamRouter.exactOutputSingle(swapParams);
        } else {
            IAerodromeSlipstreamRouter.ExactOutputParams memory swapParams = IAerodromeSlipstreamRouter
                .ExactOutputParams({
                // We need to reverse the path as we are swapping from the last token to the first, as required by Aerodrome Slipstream
                path: _encodeAerodromeSlipstreamPath(swapContext.path, swapContext.tickSpacing, true),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: toAmount,
                amountInMaximum: maxFromAmount
            });
            return aerodromeSlipstreamRouter.exactOutput(swapParams);
        }
    }

    function _swapMaxFromToExactToUniV2(uint256 toAmount, uint256 maxFromAmount, SwapContext memory swapContext)
        internal
        returns (uint256 fromAmount)
    {
        IUniswapSwapRouter02 uniswapRouter02 = IUniswapSwapRouter02(swapContext.exchangeAddresses.uniswapRouter02);
        IERC20(swapContext.path[0]).approve(address(uniswapRouter02), maxFromAmount);
        return uniswapRouter02.swapTokensForExactTokens(toAmount, maxFromAmount, swapContext.path, msg.sender);
    }

    function _swapMaxFromToExactToUniV3(uint256 toAmount, uint256 maxFromAmount, SwapContext memory swapContext)
        internal
        returns (uint256 fromAmount)
    {
        // Check that the number of fees is equal to the number of paths minus one, as required by Uniswap V3
        if (swapContext.path.length != swapContext.fees.length + 1) revert InvalidNumFees();

        IUniswapSwapRouter02 uniswapRouter02 = IUniswapSwapRouter02(swapContext.exchangeAddresses.uniswapRouter02);

        IERC20(swapContext.path[0]).approve(address(uniswapRouter02), maxFromAmount);

        if (swapContext.path.length == 2) {
            IUniswapSwapRouter02.ExactOutputSingleParams memory params = IUniswapSwapRouter02.ExactOutputSingleParams({
                tokenIn: swapContext.path[0],
                tokenOut: swapContext.path[1],
                fee: swapContext.fees[0],
                recipient: msg.sender,
                amountOut: toAmount,
                amountInMaximum: maxFromAmount,
                sqrtPriceLimitX96: 0
            });
            return uniswapRouter02.exactOutputSingle(params);
        } else {
            IUniswapSwapRouter02.ExactOutputParams memory params = IUniswapSwapRouter02.ExactOutputParams({
                // We need to reverse the path as we are swapping from the last token to the first, as required by Uniswap V3
                path: _encodeUniswapV3Path(swapContext.path, swapContext.fees, true),
                recipient: msg.sender,
                amountOut: toAmount,
                amountInMaximum: maxFromAmount
            });
            return uniswapRouter02.exactOutput(params);
        }
    }

    /// @notice Encode the path as required by the Aerodrome Slipstream router
    function _encodeAerodromeSlipstreamPath(address[] memory path, int24[] memory tickSpacing, bool reverseOrder)
        internal
        pure
        returns (bytes memory encodedPath)
    {
        if (reverseOrder) {
            encodedPath = abi.encodePacked(path[path.length - 1]);
            for (uint256 i = tickSpacing.length; i > 0; i--) {
                uint256 indexToAppend = i - 1;
                encodedPath = abi.encodePacked(encodedPath, tickSpacing[indexToAppend], path[indexToAppend]);
            }
        } else {
            encodedPath = abi.encodePacked(path[0]);
            for (uint256 i = 0; i < tickSpacing.length; i++) {
                encodedPath = abi.encodePacked(encodedPath, tickSpacing[i], path[i + 1]);
            }
        }
    }

    /// @notice Encode the path as required by the Uniswap V3 router
    function _encodeUniswapV3Path(address[] memory path, uint24[] memory fees, bool reverseOrder)
        internal
        pure
        returns (bytes memory encodedPath)
    {
        if (reverseOrder) {
            encodedPath = abi.encodePacked(path[path.length - 1]);
            for (uint256 i = fees.length; i > 0; i--) {
                uint256 indexToAppend = i - 1;
                encodedPath = abi.encodePacked(encodedPath, fees[indexToAppend], path[indexToAppend]);
            }
        } else {
            encodedPath = abi.encodePacked(path[0]);
            for (uint256 i = 0; i < fees.length; i++) {
                encodedPath = abi.encodePacked(encodedPath, fees[i], path[i + 1]);
            }
        }
    }

    function _reversePath(address[] memory path) internal pure returns (address[] memory reversedPath) {
        reversedPath = new address[](path.length);
        for (uint256 i = 0; i < path.length; i++) {
            reversedPath[i] = path[path.length - i - 1];
        }
    }
}
