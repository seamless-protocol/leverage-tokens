// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {ISwapAdapter} from "./ISwapAdapter.sol";
import {ActionDataV2} from "src/types/DataTypes.sol";

interface ILeverageRouter {
    /// @notice Struct containing the target, value, and data for a single external call.
    struct Call {
        address target; // Call target
        uint256 value; // ETH value to send
        bytes data; // Calldata you ABI-encode off-chain
    }

    /// @notice Stateless approval specification executed before calls.
    struct Approval {
        address token; // ERC-20 to approve FROM this contract
        address spender; // Router/pool that will pull the token
        uint256 amount; // Allowance to set (usually amountIn or type(uint256).max)
    }

    /// @notice Error thrown when the collateral from the swap + the collateral from the sender is less than the collateral required for the deposit
    /// @param available The collateral from the swap + the collateral from the sender, available for the deposit
    /// @param required The collateral required for the deposit
    error InsufficientCollateralForDeposit(uint256 available, uint256 required);

    /// @notice Error thrown when the cost of a swap exceeds the maximum allowed cost
    /// @param actualCost The actual cost of the swap
    /// @param maxCost The maximum allowed cost of the swap
    error MaxSwapCostExceeded(uint256 actualCost, uint256 maxCost);

    /// @notice Error thrown when the caller is not authorized to execute a function
    error Unauthorized();

    /// @notice The LeverageManager contract
    /// @return _leverageManager The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Morpho core protocol contract
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);

    /// @notice Previews the deposit function call for an amount of equity and returns all required data
    /// @param token LeverageToken to preview deposit for
    /// @param equityInCollateralAsset The amount of equity to deposit. Denominated in the collateral asset of the LeverageToken
    /// @return previewData Preview data for deposit
    ///         - collateral Amount of collateral that will be added to the LeverageToken
    ///         - debt Amount of debt that will be borrowed
    ///         - shares Amount of shares that will be minted
    ///         - tokenFee Amount of shares that will be charged for the deposit that are given to the LeverageToken
    ///         - treasuryFee Amount of shares that will be charged for the deposit that are given to the treasury
    function previewDeposit(ILeverageToken token, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionDataV2 memory);

    /// @notice The swap adapter contract used to facilitate swaps
    /// @return _swapper The swap adapter contract
    function swapper() external view returns (ISwapAdapter _swapper);

    /// @notice Deposits collateral into a LeverageToken and mints shares to the sender. Any surplus debt received from
    /// the deposit of (collateralFromSender + debt swapped to collateral) is given to the sender.
    /// @param leverageToken LeverageToken to deposit into
    /// @param collateralFromSender Collateral asset amount from the sender to deposit
    /// @param debt Amount of debt to flash loan, which is swapped to collateral and used to deposit into the LeverageToken
    /// @param minShares Minimum number of shares expected to be received by the sender
    /// @param swapContext Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)
    function deposit(
        ILeverageToken leverageToken,
        uint256 collateralFromSender,
        uint256 debt,
        uint256 minShares,
        ISwapAdapter.SwapContext memory swapContext
    ) external;

    /// @notice Execute an arbitrary external swap call. All outputToken is sent to the recipient. Any leftover inputToken is sent to the sender.
    /// Note: If the inputToken is the same as the outputToken, any leftover inputToken is sent to the recipient instead of the sender.
    /// @param approval The approval to set before the call (set token=address(0) to skip). e.g. approving a DEX to pull the inputToken from the SwapAdapter.
    /// @param call External call to perform (DEX/router).
    /// @param inputToken Input token for the swap (address(0) = ETH).
    /// @param outputToken Output token for the swap (address(0) = ETH).
    /// @param inputAmount Amount of input token for the swap, which is tranferred from the sender to the SwapAdapter.
    /// Note: If the sender transferred the required amount of input token to this contract already, this can be set to zero.
    /// @param recipient Where to send the outputToken.
    /// @return result Return data of the external call.
    function executeSwap(
        Call calldata call,
        Approval calldata approval,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        address payable recipient
    ) external payable returns (bytes memory result);

    /// @notice Redeems equity of a LeverageToken by repaying debt and burning shares
    /// @param token LeverageToken to redeem
    /// @param equityInCollateralAsset The amount of equity to receive by redeeming LeverageToken. Denominated in the collateral
    ///        asset of the LeverageToken
    /// @param maxShares Maximum shares (LeverageTokens) to redeem
    /// @param maxSwapCostInCollateralAsset The maximum amount of equity to pay for the redeem of the LeverageToken
    ///        to use to help repay the debt flash loan due to the swap of debt to collateral being unfavorable
    /// @param swapContext Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)
    function redeem(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        uint256 maxShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external;
}
