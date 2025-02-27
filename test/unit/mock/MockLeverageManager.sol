// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract MockLeverageManager is Test {
    uint256 public BASE_RATIO = 1e8;

    struct StrategyData {
        IERC20 strategyToken;
        ILendingAdapter lendingAdapter;
        IERC20 collateralAsset;
        IERC20 debtAsset;
        uint256 targetCollateralRatio;
    }

    struct DepositParams {
        IStrategy strategy;
        uint256 equityInCollateralAsset;
        uint256 minShares;
    }

    struct PreviewDepositParams {
        IStrategy strategy;
        uint256 equityInCollateralAsset;
    }

    struct MockDepositData {
        uint256 collateral;
        uint256 debt;
        uint256 shares;
        bool isExecuted;
    }

    struct MockPreviewDepositData {
        uint256 collateralToAdd;
        uint256 debtToBorrow;
        uint256 shares;
        uint256 sharesFee;
    }

    mapping(IStrategy => StrategyData) public strategies;

    mapping(IStrategy => StrategyState) public strategyStates;

    mapping(bytes32 => MockDepositData[]) public mockDepositData;

    mapping(bytes32 => MockPreviewDepositData) public mockPreviewDepositData;

    function getStrategyCollateralAsset(IStrategy strategy) external view returns (IERC20) {
        return strategies[strategy].collateralAsset;
    }

    function getStrategyLendingAdapter(IStrategy strategy) external view returns (ILendingAdapter) {
        return strategies[strategy].lendingAdapter;
    }

    function getStrategyState(IStrategy strategy) external view returns (StrategyState memory) {
        return strategyStates[strategy];
    }

    function getStrategyTargetCollateralRatio(IStrategy strategy) external view returns (uint256) {
        return strategies[strategy].targetCollateralRatio;
    }

    function getStrategyDebtAsset(IStrategy strategy) external view returns (IERC20) {
        return strategies[strategy].debtAsset;
    }

    function setStrategyData(IStrategy strategy, StrategyData memory _strategyData) external {
        strategies[strategy] = _strategyData;
    }

    function setStrategyTargetCollateralRatio(IStrategy strategy, uint256 _targetCollateralRatio) external {
        strategies[strategy].targetCollateralRatio = _targetCollateralRatio;
    }

    function setStrategyState(IStrategy strategy, StrategyState memory _strategyState) external {
        strategyStates[strategy] = _strategyState;
    }

    function setMockPreviewDepositData(
        PreviewDepositParams memory _previewDepositParams,
        MockPreviewDepositData memory _mockPreviewDepositData
    ) external {
        bytes32 mockPreviewDepositDataKey =
            keccak256(abi.encode(_previewDepositParams.strategy, _previewDepositParams.equityInCollateralAsset));
        mockPreviewDepositData[mockPreviewDepositDataKey] = _mockPreviewDepositData;
    }

    function setMockDepositData(DepositParams memory _depositParams, MockDepositData memory _mockDepositData)
        external
    {
        bytes32 mockDepositDataKey = keccak256(
            abi.encode(_depositParams.strategy, _depositParams.equityInCollateralAsset, _depositParams.minShares)
        );
        mockDepositData[mockDepositDataKey].push(_mockDepositData);
    }

    function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        external
        view
        returns (uint256, uint256, uint256, uint256)
    {
        bytes32 mockPreviewDepositDataKey = keccak256(abi.encode(strategy, equityInCollateralAsset));
        return (
            mockPreviewDepositData[mockPreviewDepositDataKey].collateralToAdd,
            mockPreviewDepositData[mockPreviewDepositDataKey].debtToBorrow,
            mockPreviewDepositData[mockPreviewDepositDataKey].shares,
            mockPreviewDepositData[mockPreviewDepositDataKey].sharesFee
        );
    }

    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (uint256, uint256, uint256, uint256)
    {
        StrategyData storage strategyData = strategies[strategy];

        bytes32 mockDepositDataKey = keccak256(abi.encode(strategy, equityInCollateralAsset, minShares));
        MockDepositData[] memory mockDepositDataArray = mockDepositData[mockDepositDataKey];

        // Find the first unexecuted mock deposit data
        for (uint256 i = 0; i < mockDepositDataArray.length; i++) {
            MockDepositData memory _mockDepositData = mockDepositDataArray[i];
            if (!_mockDepositData.isExecuted) {
                // Transfer the required collateral to the LeverageManager
                SafeERC20.safeTransferFrom(
                    strategyData.collateralAsset, msg.sender, address(this), _mockDepositData.collateral
                );

                // Deal the sender the required debt
                deal(address(strategyData.debtAsset), address(this), _mockDepositData.debt);
                strategyData.debtAsset.transfer(msg.sender, _mockDepositData.debt);

                // Deal the sender the shares
                deal(address(strategyData.strategyToken), address(this), _mockDepositData.shares);
                strategyData.strategyToken.transfer(msg.sender, _mockDepositData.shares);

                // Set the mock deposit data to executed and return the shares minted
                mockDepositData[mockDepositDataKey][i].isExecuted = true;
                return (_mockDepositData.collateral, _mockDepositData.debt, _mockDepositData.shares, 0);
            }
        }

        // If no mock deposit data is found, revert
        revert("No mock deposit data found for MockLeverageManager.deposit");
    }
}
