// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";

contract MockLeverageManager is Test {
    struct DepositParams {
        IStrategy strategy;
        uint256 equityInCollateralAsset;
        uint256 minShares;
    }

    struct PreviewDepositParams {
        IStrategy strategy;
        uint256 equityInCollateralAsset;
    }

    struct StrategyData {
        IERC20 collateralAsset;
        IERC20 debtAsset;
        IERC20 strategyToken;
    }

    struct MockDepositData {
        uint256 requiredCollateral;
        uint256 requiredDebt;
        uint256 shares;
        bool isExecuted;
    }

    struct MockPreviewDepositData {
        uint256 shares;
        uint256 requiredCollateral;
        uint256 requiredDebt;
    }

    mapping(IStrategy => StrategyData) public strategies;

    mapping(bytes32 => MockDepositData[]) public mockDepositData;

    mapping(bytes32 => MockPreviewDepositData) public mockPreviewDepositData;

    function getStrategyCollateralAsset(IStrategy strategy) external view returns (IERC20) {
        return strategies[strategy].collateralAsset;
    }

    function getStrategyDebtAsset(IStrategy strategy) external view returns (IERC20) {
        return strategies[strategy].debtAsset;
    }

    function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        external
        view
        returns (uint256, uint256, uint256)
    {
        MockPreviewDepositData memory _mockPreviewDepositData =
            mockPreviewDepositData[keccak256(abi.encode(strategy, equityInCollateralAsset))];
        return (
            _mockPreviewDepositData.shares,
            _mockPreviewDepositData.requiredCollateral,
            _mockPreviewDepositData.requiredDebt
        );
    }

    function setStrategyData(IStrategy strategy, IERC20 collateralAsset, IERC20 debtAsset, IERC20 strategyToken)
        external
    {
        strategies[strategy].collateralAsset = collateralAsset;
        strategies[strategy].debtAsset = debtAsset;
        strategies[strategy].strategyToken = strategyToken;
    }

    function setMockDepositData(DepositParams memory _depositParams, MockDepositData memory _mockDepositData)
        external
    {
        bytes32 mockDepositDataKey = keccak256(
            abi.encode(_depositParams.strategy, _depositParams.equityInCollateralAsset, _depositParams.minShares)
        );
        mockDepositData[mockDepositDataKey].push(_mockDepositData);
    }

    function setMockPreviewDepositData(
        PreviewDepositParams memory _previewDepositParams,
        MockPreviewDepositData memory _mockPreviewDepositData
    ) external {
        bytes32 mockDepositDataKey =
            keccak256(abi.encode(_previewDepositParams.strategy, _previewDepositParams.equityInCollateralAsset));
        mockPreviewDepositData[mockDepositDataKey] = _mockPreviewDepositData;
    }

    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (uint256 shares)
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
                    strategyData.collateralAsset, msg.sender, address(this), _mockDepositData.requiredCollateral
                );

                // Deal the sender the required debt
                deal(address(strategyData.debtAsset), msg.sender, _mockDepositData.requiredDebt);

                // Deal the sender the shares
                deal(address(strategyData.strategyToken), msg.sender, _mockDepositData.shares);

                // Set the mock deposit data to executed and return the shares minted
                mockDepositData[mockDepositDataKey][i].isExecuted = true;
                return _mockDepositData.shares;
            }
        }

        // If no mock deposit data is found, revert
        revert("No mock deposit data found for MockLeverageManager.deposit");
    }
}
