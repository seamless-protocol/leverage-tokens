// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {ISwapAdapter} from "./ISwapAdapter.sol";
import {ActionDataV2, ExternalAction} from "src/types/DataTypes.sol";

interface ILeverageRouter {
    /// @notice Struct containing the token and spender for an approval.
    struct Approval {
        // Token to approve
        IERC20 token;
        // Spender to approve the token to
        address spender;
    }

    /// @notice Struct containing the target, value, and data for a single external call.
    struct Call {
        address target; // Call target
        uint256 value; // ETH value to send
        bytes data; // Calldata you ABI-encode off-chain
        Approval approval; // Optional approval to use for the call. Approves type(uint256).max of the token to the spender. After the call, the allowance is reset to 0.
    }

    /// @notice Deposit related parameters to pass to the Morpho flash loan callback handler for deposits
    struct DepositParams {
        // Address of the sender of the deposit
        address sender;
        // LeverageToken to deposit into
        ILeverageToken leverageToken;
        // Amount of collateral from the sender to deposit
        uint256 collateralFromSender;
        // Minimum amount of shares (LeverageTokens) to receive
        uint256 minShares;
        // External calls to execute for the swap of flash loaned debt to collateral
        Call[] swapCalls;
    }

    /// @notice Redeem related parameters to pass to the Morpho flash loan callback handler for redeems
    struct RedeemParams {
        // LeverageToken to redeem from
        ILeverageToken token;
        // Amount of equity to receive by redeeming, denominated in the collateral asset
        uint256 equityInCollateralAsset;
        // Amount of LeverageToken shares to redeem for the equity
        uint256 shares;
        // Maximum amount of shares (LeverageTokens) to be burned during the redeem
        uint256 maxShares;
        // Maximum cost to the sender for the swap of debt to collateral during the redeem to repay the flash loan,
        // denominated in the collateral asset. This cost is applied to the equity being received
        uint256 maxSwapCostInCollateralAsset;
        // Address of the sender of the redeem, whose shares will be burned and the equity will be transferred to
        address sender;
        // Swap context for the debt swap
        ISwapAdapter.SwapContext swapContext;
    }

    /// @notice Morpho flash loan callback data to pass to the Morpho flash loan callback handler
    struct MorphoCallbackData {
        ExternalAction action;
        bytes data;
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

    /// @notice Converts an amount of equity to an amount of collateral for a LeverageToken, based on the current
    /// collateral ratio of the LeverageToken
    /// @param token LeverageToken to convert equity to collateral for
    /// @param equityInCollateralAsset Amount of equity to convert to collateral, denominated in the collateral asset of the LeverageToken
    /// @return collateral Amount of collateral that correspond to the equity amount
    function convertEquityToCollateral(ILeverageToken token, uint256 equityInCollateralAsset)
        external
        view
        returns (uint256 collateral);

    /// @notice The LeverageManager contract
    /// @return _leverageManager The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Morpho core protocol contract
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);

    /// @notice Previews the deposit function call for an amount of equity and returns all required data
    /// @param token LeverageToken to preview deposit for
    /// @param collateralFromSender The amount of collateral from the sender to deposit
    /// @return previewData Preview data for deposit
    ///         - collateral Total amount of collateral that will be added to the LeverageToken (including collateral from swapping flash loaned debt)
    ///         - debt Amount of debt that will be borrowed
    ///         - shares Amount of shares that will be minted
    ///         - tokenFee Amount of shares that will be charged for the deposit that are given to the LeverageToken
    ///         - treasuryFee Amount of shares that will be charged for the deposit that are given to the treasury
    function previewDeposit(ILeverageToken token, uint256 collateralFromSender)
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
    /// @param flashLoanAmount Amount of debt to flash loan, which is swapped to collateral and used to deposit into the LeverageToken
    /// @param minShares Minimum number of shares expected to be received by the sender
    /// @param swapCalls External calls to execute for the swap of flash loaned debt to collateral for the LeverageToken deposit
    /// @dev Before each external call, the target contract is approved to spend flashLoanAmount of the debt asset
    function deposit(
        ILeverageToken leverageToken,
        uint256 collateralFromSender,
        uint256 flashLoanAmount,
        uint256 minShares,
        Call[] calldata swapCalls
    ) external;

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
