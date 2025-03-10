// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IMorphoFlashLoanCallback} from "@morpho-blue/interfaces/IMorphoCallbacks.sol";

// Internal imports
import {ILeverageManager} from "./interfaces/ILeverageManager.sol";
import {IRebalanceModuleLIFI} from "./interfaces/IRebalanceModuleLIFI.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {ActionType, RebalanceAction, TokenTransfer} from "./types/DataTypes.sol";

/// @title RebalanceModuleLIFI
/// @notice A module for executing rebalancing operations using LIFI for swaps
contract RebalanceModuleLIFI is IRebalanceModuleLIFI {
    using SafeERC20 for IERC20;

    IMorpho public immutable override morpho;
    ILeverageManager public immutable override leverageManager;
    address public immutable override lifi;

    /// @notice Ensures the caller is the Morpho contract
    modifier onlyMorpho() {
        if (msg.sender != address(morpho)) {
            revert Unauthorized();
        }
        _;
    }

    /// @dev Data passed through flash loan callback
    struct MorphoCallbackData {
        /// @dev True if the rebalance is over-collateralized, false if it is under-collateralized
        bool isOverCollateralized;
        /// @dev Strategy to rebalance
        IStrategy strategy;
        /// @dev Amount of debt to borrow or collateral to remove, depending on rebalance type
        uint256 amount;
        /// @dev LIFI provider swap data that will swap borrowed debt to collateral
        bytes providerSwapData;
    }

    /// @notice Constructs the RebalanceModuleLIFI contract
    /// @param _morpho Address of the Morpho contract
    /// @param _leverageManager Address of the LeverageManager contract
    /// @param _lifi Address of the LIFI contract

    constructor(address _morpho, address _leverageManager, address _lifi) {
        morpho = IMorpho(_morpho);
        leverageManager = ILeverageManager(_leverageManager);
        lifi = _lifi;
    }

    /// @inheritdoc IRebalanceModuleLIFI
    function rebalanceOverCollateralized(
        IStrategy strategy,
        uint256 collateralToAdd,
        uint256 debtToBorrow,
        bytes memory providerSwapData
    ) external {
        IERC20 collateralToken = leverageManager.getStrategyCollateralAsset(strategy);

        bytes memory params = abi.encode(
            MorphoCallbackData({
                isOverCollateralized: true,
                strategy: strategy,
                amount: debtToBorrow,
                providerSwapData: providerSwapData
            })
        );

        morpho.flashLoan(address(collateralToken), collateralToAdd, params);

        emit RebalanceExecuted(strategy, collateralToAdd, debtToBorrow, providerSwapData);
    }

    function rebalanceUnderCollateralized(
        IStrategy strategy,
        uint256 collateralToRemove,
        uint256 debtToRepay,
        bytes memory providerSwapData
    ) external {
        IERC20 debtToken = leverageManager.getStrategyDebtAsset(strategy);

        bytes memory params = abi.encode(
            MorphoCallbackData({
                isOverCollateralized: false,
                strategy: strategy,
                amount: collateralToRemove,
                providerSwapData: providerSwapData
            })
        );

        morpho.flashLoan(address(debtToken), debtToRepay, params);
    }

    /// @inheritdoc IMorphoFlashLoanCallback
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override onlyMorpho {
        MorphoCallbackData memory params = abi.decode(data, (MorphoCallbackData));

        if (params.isOverCollateralized) {
            _executeRebalanceOverCollateralized(params.strategy, assets, params.amount, params.providerSwapData);
        } else {
            _executeRebalanceUnderCollateralized(params.strategy, params.amount, assets, params.providerSwapData);
        }
    }

    /// @notice Executes a rebalance operation for an over-collateralized position
    /// @param strategy The strategy being rebalanced
    /// @param collateralToAdd The amount of collateral being added
    /// @param debtToBorrow The amount of debt being borrowed
    /// @param providerSwapData The encoded swap data for LIFI to swap debt for collateral
    function _executeRebalanceOverCollateralized(
        IStrategy strategy,
        uint256 collateralToAdd,
        uint256 debtToBorrow,
        bytes memory providerSwapData
    ) internal {
        (RebalanceAction[] memory actions, TokenTransfer[] memory tokensIn, TokenTransfer[] memory tokensOut) =
            _prepareRebalanceParamsOverCollateralized(strategy, collateralToAdd, debtToBorrow);

        IERC20 collateralToken = leverageManager.getStrategyCollateralAsset(strategy);
        IERC20 debtToken = leverageManager.getStrategyDebtAsset(strategy);

        // Approve leverage manager and execute rebalance
        collateralToken.approve(address(leverageManager), collateralToAdd);
        leverageManager.rebalance(actions, tokensIn, tokensOut);

        // Execute swap via LIFI
        _executeSwapOnLifi(debtToken, debtToBorrow, providerSwapData);

        // Handle excess collateral and flash loan repayment
        uint256 excessCollateral = collateralToken.balanceOf(address(this)) - collateralToAdd;
        collateralToken.safeTransfer(msg.sender, excessCollateral);

        collateralToken.approve(address(morpho), collateralToAdd);
    }

    /// @notice Executes a rebalance operation for an under-collateralized position
    /// @param strategy The strategy being rebalanced
    /// @param collateralToRemove The amount of collateral being removed
    /// @param debtToRepay The amount of debt being repaid
    /// @param providerSwapData The encoded swap data for LIFI to swap collateral for debt
    function _executeRebalanceUnderCollateralized(
        IStrategy strategy,
        uint256 collateralToRemove,
        uint256 debtToRepay,
        bytes memory providerSwapData
    ) internal {
        (RebalanceAction[] memory actions, TokenTransfer[] memory tokensIn, TokenTransfer[] memory tokensOut) =
            _prepareRebalanceParamsUnderCollateralized(strategy, collateralToRemove, debtToRepay);

        IERC20 collateralToken = leverageManager.getStrategyCollateralAsset(strategy);
        IERC20 debtToken = leverageManager.getStrategyDebtAsset(strategy);

        // Approve leverage manager and execute rebalance
        debtToken.approve(address(leverageManager), debtToRepay);
        leverageManager.rebalance(actions, tokensIn, tokensOut);

        // Execute swap via LIFI
        _executeSwapOnLifi(collateralToken, collateralToRemove, providerSwapData);

        // Handle excess debt and flash loan repayment
        uint256 excessDebt = debtToken.balanceOf(address(this)) - debtToRepay;
        debtToken.safeTransfer(msg.sender, excessDebt);

        debtToken.approve(address(morpho), debtToRepay);
    }

    /// @notice Prepares parameters for over-collateralized rebalance
    /// @param strategy The strategy being rebalanced
    /// @param collateralToAdd The amount of collateral being added
    /// @param debtToBorrow The amount of debt being borrowed
    /// @return actions Array of rebalance actions to execute
    /// @return tokensIn Array of tokens being transferred in
    /// @return tokensOut Array of tokens being transferred out
    function _prepareRebalanceParamsOverCollateralized(
        IStrategy strategy,
        uint256 collateralToAdd,
        uint256 debtToBorrow
    )
        internal
        view
        returns (RebalanceAction[] memory actions, TokenTransfer[] memory tokensIn, TokenTransfer[] memory tokensOut)
    {
        IERC20 collateralToken = leverageManager.getStrategyCollateralAsset(strategy);
        IERC20 debtToken = leverageManager.getStrategyDebtAsset(strategy);

        actions = new RebalanceAction[](2);
        actions[0] =
            RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: collateralToAdd});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: debtToBorrow});

        tokensIn = new TokenTransfer[](1);
        tokensIn[0] = TokenTransfer({token: address(collateralToken), amount: collateralToAdd});

        tokensOut = new TokenTransfer[](1);
        tokensOut[0] = TokenTransfer({token: address(debtToken), amount: debtToBorrow});
    }

    /// @notice Prepares parameters for under-collateralized rebalance
    /// @param strategy The strategy being rebalanced
    /// @param collateralToRemove The amount of collateral being removed
    /// @param debtToRepay The amount of debt being repaid
    /// @return actions Array of rebalance actions to execute
    /// @return tokensIn Array of tokens being transferred in
    /// @return tokensOut Array of tokens being transferred out
    function _prepareRebalanceParamsUnderCollateralized(
        IStrategy strategy,
        uint256 collateralToRemove,
        uint256 debtToRepay
    )
        internal
        view
        returns (RebalanceAction[] memory actions, TokenTransfer[] memory tokensIn, TokenTransfer[] memory tokensOut)
    {
        IERC20 collateralToken = leverageManager.getStrategyCollateralAsset(strategy);
        IERC20 debtToken = leverageManager.getStrategyDebtAsset(strategy);

        actions = new RebalanceAction[](2);
        actions[0] =
            RebalanceAction({strategy: strategy, actionType: ActionType.RemoveCollateral, amount: collateralToRemove});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Repay, amount: debtToRepay});

        tokensIn = new TokenTransfer[](1);
        tokensIn[0] = TokenTransfer({token: address(debtToken), amount: debtToRepay});

        tokensOut = new TokenTransfer[](1);
        tokensOut[0] = TokenTransfer({token: address(collateralToken), amount: collateralToRemove});
    }

    /// @notice Executes a swap operation through LIFI
    /// @param token The token to swap
    /// @param amountIn The amount of token to swap
    /// @param providerSwapData The encoded swap data for LIFI
    function _executeSwapOnLifi(IERC20 token, uint256 amountIn, bytes memory providerSwapData) internal {
        token.approve(address(lifi), amountIn);

        (bool success,) = lifi.call{value: 0}(providerSwapData);
        if (!success) {
            revert SwapFailed();
        }
    }
}
