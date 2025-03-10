// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ActionData, StrategyState} from "src/types/DataTypes.sol";

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

    struct WithdrawParams {
        IStrategy strategy;
        uint256 equityInCollateralAsset;
        uint256 maxShares;
    }

    struct PreviewParams {
        IStrategy strategy;
        uint256 equityInCollateralAsset;
    }

    struct MockDepositData {
        uint256 collateral;
        uint256 debt;
        uint256 shares;
        bool isExecuted;
    }

    struct MockWithdrawData {
        uint256 collateral;
        uint256 debt;
        uint256 shares;
        bool isExecuted;
    }

    struct MockPreviewDepositData {
        uint256 collateralToAdd;
        uint256 debtToBorrow;
        uint256 shares;
        uint256 strategyFee;
        uint256 treasuryFee;
    }

    struct MockPreviewWithdrawData {
        uint256 collateralToRemove;
        uint256 debtToRepay;
        uint256 shares;
        uint256 strategyFee;
        uint256 treasuryFee;
    }

    mapping(IStrategy => StrategyData) public strategies;

    mapping(IStrategy => StrategyState) public strategyStates;

    mapping(bytes32 => MockDepositData[]) public mockDepositData;

    mapping(bytes32 => MockWithdrawData[]) public mockWithdrawData;

    mapping(bytes32 => MockPreviewDepositData) public mockPreviewDepositData;

    mapping(bytes32 => MockPreviewWithdrawData) public mockPreviewWithdrawData;

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
        PreviewParams memory _previewDepositParams,
        MockPreviewDepositData memory _mockPreviewDepositData
    ) external {
        bytes32 mockPreviewDepositDataKey =
            keccak256(abi.encode(_previewDepositParams.strategy, _previewDepositParams.equityInCollateralAsset));
        mockPreviewDepositData[mockPreviewDepositDataKey] = _mockPreviewDepositData;
    }

    function setMockPreviewWithdrawData(
        PreviewParams memory _previewWithdrawParams,
        MockPreviewWithdrawData memory _mockPreviewWithdrawData
    ) external {
        bytes32 mockPreviewWithdrawDataKey =
            keccak256(abi.encode(_previewWithdrawParams.strategy, _previewWithdrawParams.equityInCollateralAsset));
        mockPreviewWithdrawData[mockPreviewWithdrawDataKey] = _mockPreviewWithdrawData;
    }

    function setMockWithdrawData(WithdrawParams memory _withdrawParams, MockWithdrawData memory _mockWithdrawData)
        external
    {
        bytes32 mockWithdrawDataKey = keccak256(
            abi.encode(_withdrawParams.strategy, _withdrawParams.equityInCollateralAsset, _withdrawParams.maxShares)
        );
        mockWithdrawData[mockWithdrawDataKey].push(_mockWithdrawData);
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
        returns (ActionData memory)
    {
        bytes32 mockPreviewDepositDataKey = keccak256(abi.encode(strategy, equityInCollateralAsset));

        return ActionData({
            collateral: mockPreviewDepositData[mockPreviewDepositDataKey].collateralToAdd,
            debt: mockPreviewDepositData[mockPreviewDepositDataKey].debtToBorrow,
            equity: equityInCollateralAsset,
            shares: mockPreviewDepositData[mockPreviewDepositDataKey].shares,
            strategyFee: mockPreviewDepositData[mockPreviewDepositDataKey].strategyFee,
            treasuryFee: mockPreviewDepositData[mockPreviewDepositDataKey].treasuryFee
        });
    }

    function previewWithdraw(IStrategy strategy, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory)
    {
        bytes32 mockPreviewWithdrawDataKey = keccak256(abi.encode(strategy, equityInCollateralAsset));
        return ActionData({
            collateral: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].collateralToRemove,
            debt: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].debtToRepay,
            equity: equityInCollateralAsset,
            shares: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].shares,
            strategyFee: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].strategyFee,
            treasuryFee: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].treasuryFee
        });
    }

    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (ActionData memory)
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

                // Give the sender the required debt
                deal(address(strategyData.debtAsset), address(this), _mockDepositData.debt);
                strategyData.debtAsset.transfer(msg.sender, _mockDepositData.debt);

                // Give the sender the shares
                deal(address(strategyData.strategyToken), address(this), _mockDepositData.shares);
                strategyData.strategyToken.transfer(msg.sender, _mockDepositData.shares);

                // Set the mock deposit data to executed and return the shares minted
                mockDepositData[mockDepositDataKey][i].isExecuted = true;
                return ActionData({
                    equity: equityInCollateralAsset,
                    collateral: _mockDepositData.collateral,
                    debt: _mockDepositData.debt,
                    shares: _mockDepositData.shares,
                    strategyFee: 0,
                    treasuryFee: 0
                });
            }
        }

        // If no mock deposit data is found, revert
        revert("No mock deposit data found for MockLeverageManager.deposit");
    }

    function withdraw(IStrategy strategy, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (ActionData memory)
    {
        StrategyData storage strategyData = strategies[strategy];

        bytes32 mockWithdrawDataKey = keccak256(abi.encode(strategy, equityInCollateralAsset, maxShares));
        MockWithdrawData[] memory mockWithdrawDataArray = mockWithdrawData[mockWithdrawDataKey];

        // Find the first unexecuted mock deposit data
        for (uint256 i = 0; i < mockWithdrawDataArray.length; i++) {
            MockWithdrawData memory _mockWithdrawData = mockWithdrawDataArray[i];
            if (!_mockWithdrawData.isExecuted) {
                // Transfer the required debt to the LeverageManager
                SafeERC20.safeTransferFrom(strategyData.debtAsset, msg.sender, address(this), _mockWithdrawData.debt);

                // Give the sender the required collateral
                deal(address(strategyData.collateralAsset), address(this), _mockWithdrawData.collateral);
                strategyData.collateralAsset.transfer(msg.sender, _mockWithdrawData.collateral);

                // Burn the sender's shares
                deal(address(strategyData.strategyToken), address(this), _mockWithdrawData.shares);
                ERC20Mock(address(strategyData.strategyToken)).burn(msg.sender, _mockWithdrawData.shares);

                // Set the mock withdraw data to executed
                mockWithdrawData[mockWithdrawDataKey][i].isExecuted = true;
                return ActionData({
                    equity: equityInCollateralAsset,
                    collateral: _mockWithdrawData.collateral,
                    debt: _mockWithdrawData.debt,
                    shares: _mockWithdrawData.shares,
                    strategyFee: 0,
                    treasuryFee: 0
                });
            }
        }

        // If no mock withdraw data is found, revert
        revert("No mock withdraw data found for MockLeverageManager.withdraw");
    }
}
