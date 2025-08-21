// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEtherFiL2ModeSyncPool} from "./IEtherFiL2ModeSyncPool.sol";

interface ISwapAdapter {
    /// @notice The exchanges supported by SwapAdapter
    enum Exchange {
        AERODROME,
        AERODROME_SLIPSTREAM,
        ETHERFI,
        UNISWAP_V2,
        UNISWAP_V3
    }

    /// @notice Contextual data required for EtherFi swaps using the EtherFi L2 Mode Sync Pool
    struct EtherFiSwapContext {
        // The EtherFi L2 Mode Sync Pool to use for the swap
        IEtherFiL2ModeSyncPool etherFiL2ModeSyncPool;
        // The token to swap for weETH
        address tokenIn;
        // The address of weETH
        address weETH;
        // The referral to use for the swap
        address referral;
    }

    /// @notice Addresses required to facilitate swaps on the supported exchanges
    struct ExchangeAddresses {
        address aerodromeRouter;
        address aerodromePoolFactory;
        address aerodromeSlipstreamRouter;
        address uniswapSwapRouter02;
        address uniswapV2Router02;
    }

    /// @notice Contextextual data required for a swap
    struct SwapContext {
        // The token swap path
        address[] path;
        // The encoded path of tokens to swap. Required by Uniswap V3 and Aerodrome Slipstream
        bytes encodedPath;
        // The fees to use for the swap. For Uniswap V3, fees are used to identify unique pools
        uint24[] fees;
        // The tick spacing to use for the swap. For Aerodrome Slipstream, tickSpacing is used to identify unique pools
        int24[] tickSpacing;
        // The exchange to use for the swap
        Exchange exchange;
        // The addresses required to facilitate swaps on the supported exchanges
        ExchangeAddresses exchangeAddresses;
        // Additional encoded data required for the swap
        bytes additionalData;
    }

    /// @notice Struct containing the target, value, and data for a single external call.
    struct Call {
        address target; // DEX/router/pool
        uint256 value; // ETH value to send
        bytes data; // Calldata you ABI-encode off-chain
    }

    /// @notice Stateless approval specification executed before calls.
    struct Approval {
        address token; // ERC-20 to approve FROM this contract
        address spender; // Router/pool that will pull the token
        uint256 amount; // Allowance to set (usually amountIn or type(uint256).max)
    }

    /// @notice Emitted when a swap is executed using an arbitrary external call
    event Executed(
        Call call, Approval approval, address inputToken, address outputToken, address recipient, bytes result
    );

    /// @notice Error thrown when the number of ticks is invalid
    error InvalidNumTicks();

    /// @notice Error thrown when the number of fees is invalid
    error InvalidNumFees();

    /// @notice Execute an approval (optional), then an arbitrary external swap call. All outputToken is sent to the
    /// recipient. Any leftover inputToken is sent to the sender.

    /// @notice Execute an arbitrary external swap call. All outputToken is sent to the recipient. Any leftover inputToken is sent to the sender.
    /// Note: If the inputToken is the same as the outputToken, any leftover inputToken is sent to the recipient instead of the sender.
    /// @param approval The approval to set before the call (set token=address(0) to skip). e.g. approving a DEX to pull the inputToken from the SwapAdapter.
    /// @param call External call to perform (DEX/router).
    /// @param inputToken Input token for the swap (address(0) = ETH).
    /// @param outputToken Output token for the swap (address(0) = ETH).
    /// @param inputAmount Amount of input token for the swap, which is tranferred from the sender to the SwapAdapter.
    /// Note: If the sender transferred the required amount of input token to this contract already, this can be set to zero.
    /// @param recipient Where to send the output and any leftover ETH.
    /// @return result Return data of the external call.
    function execute(
        Call calldata call,
        Approval calldata approval,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        address payable recipient
    ) external payable returns (bytes memory result);

    /// @notice Swap tokens from the `inputToken` to the `outputToken` using the specified provider
    /// @dev The `outputToken` must be encoded in the `swapContext` path
    /// @param inputToken Token to swap from
    /// @param inputAmount Amount of tokens to swap
    /// @param minOutputAmount Minimum amount of tokens to receive
    /// @param swapContext Swap context to use for the swap (which exchange to use, the swap path, tick spacing, etc.)
    /// @return outputAmount Amount of tokens received
    function swapExactInput(
        IERC20 inputToken,
        uint256 inputAmount,
        uint256 minOutputAmount,
        SwapContext memory swapContext
    ) external returns (uint256 outputAmount);

    /// @notice Swap tokens from the `inputToken` to the `outputToken` using the specified provider
    /// @dev The `outputToken` must be encoded in the `swapContext` path
    /// @param inputToken Token to swap from
    /// @param outputAmount Amount of tokens to receive
    /// @param maxInputAmount Maximum amount of tokens to swap
    /// @param swapContext Swap context to use for the swap (which exchange to use, the swap path, tick spacing, etc.)
    /// @return inputAmount Amount of tokens swapped
    function swapExactOutput(
        IERC20 inputToken,
        uint256 outputAmount,
        uint256 maxInputAmount,
        SwapContext memory swapContext
    ) external returns (uint256 inputAmount);
}
