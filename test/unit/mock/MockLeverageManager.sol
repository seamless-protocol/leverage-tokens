// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";
// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState, ActionData, RebalanceAction} from "src/types/DataTypes.sol";

contract MockLeverageManager is Test {
    uint256 public BASE_RATIO = 1e18;

    struct LeverageTokenData {
        ILeverageToken leverageToken;
        ILendingAdapter lendingAdapter;
        IERC20 collateralAsset;
        IERC20 debtAsset;
    }

    struct MintParams {
        ILeverageToken leverageToken;
        uint256 equityInCollateralAsset;
        uint256 minShares;
    }

    struct WithdrawParams {
        ILeverageToken leverageToken;
        uint256 equityInCollateralAsset;
        uint256 maxShares;
    }

    struct PreviewParams {
        ILeverageToken leverageToken;
        uint256 equityInCollateralAsset;
    }

    struct MockMintData {
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

    struct MockPreviewMintData {
        uint256 collateralToAdd;
        uint256 debtToBorrow;
        uint256 shares;
        uint256 tokenFee;
        uint256 treasuryFee;
    }

    struct MockPreviewWithdrawData {
        uint256 collateralToRemove;
        uint256 debtToRepay;
        uint256 shares;
        uint256 tokenFee;
        uint256 treasuryFee;
    }

    mapping(ILeverageToken => LeverageTokenData) public leverageTokens;

    mapping(ILeverageToken => LeverageTokenState) public leverageTokenStates;

    mapping(bytes32 => MockMintData[]) public mockMintData;

    mapping(bytes32 => MockWithdrawData[]) public mockWithdrawData;

    mapping(bytes32 => MockPreviewMintData) public mockPreviewMintData;

    mapping(bytes32 => MockPreviewWithdrawData) public mockPreviewWithdrawData;

    mapping(ILeverageToken => address) public leverageTokenRebalanceAdapter;

    function getLeverageTokenCollateralAsset(ILeverageToken leverageToken) external view returns (IERC20) {
        return leverageTokens[leverageToken].collateralAsset;
    }

    function getLeverageTokenLendingAdapter(ILeverageToken leverageToken) external view returns (ILendingAdapter) {
        return leverageTokens[leverageToken].lendingAdapter;
    }

    function getLeverageTokenRebalanceAdapter(ILeverageToken leverageToken) public view returns (address) {
        return leverageTokenRebalanceAdapter[leverageToken];
    }

    function getLeverageTokenState(ILeverageToken leverageToken) external view returns (LeverageTokenState memory) {
        return leverageTokenStates[leverageToken];
    }

    function getLeverageTokenDebtAsset(ILeverageToken leverageToken) external view returns (IERC20) {
        return leverageTokens[leverageToken].debtAsset;
    }

    function setLeverageTokenData(ILeverageToken leverageToken, LeverageTokenData memory _leverageTokenData) external {
        leverageTokens[leverageToken] = _leverageTokenData;
    }

    function setLeverageTokenState(ILeverageToken leverageToken, LeverageTokenState memory _leverageTokenState)
        external
    {
        leverageTokenStates[leverageToken] = _leverageTokenState;
    }

    function setLeverageTokenRebalanceAdapter(ILeverageToken leverageToken, address _rebalanceAdapter) external {
        leverageTokenRebalanceAdapter[leverageToken] = _rebalanceAdapter;
    }

    function setMockPreviewMintData(
        PreviewParams memory _previewMintParams,
        MockPreviewMintData memory _mockPreviewMintData
    ) external {
        bytes32 mockPreviewMintDataKey =
            keccak256(abi.encode(_previewMintParams.leverageToken, _previewMintParams.equityInCollateralAsset));
        mockPreviewMintData[mockPreviewMintDataKey] = _mockPreviewMintData;
    }

    function setMockPreviewWithdrawData(
        PreviewParams memory _previewWithdrawParams,
        MockPreviewWithdrawData memory _mockPreviewWithdrawData
    ) external {
        bytes32 mockPreviewWithdrawDataKey =
            keccak256(abi.encode(_previewWithdrawParams.leverageToken, _previewWithdrawParams.equityInCollateralAsset));
        mockPreviewWithdrawData[mockPreviewWithdrawDataKey] = _mockPreviewWithdrawData;
    }

    function setMockWithdrawData(WithdrawParams memory _withdrawParams, MockWithdrawData memory _mockWithdrawData)
        external
    {
        bytes32 mockWithdrawDataKey = keccak256(
            abi.encode(
                _withdrawParams.leverageToken, _withdrawParams.equityInCollateralAsset, _withdrawParams.maxShares
            )
        );
        mockWithdrawData[mockWithdrawDataKey].push(_mockWithdrawData);
    }

    function setMockMintData(MintParams memory _mintParams, MockMintData memory _mockMintData) external {
        bytes32 mockMintDataKey =
            keccak256(abi.encode(_mintParams.leverageToken, _mintParams.equityInCollateralAsset, _mintParams.minShares));
        mockMintData[mockMintDataKey].push(_mockMintData);
    }

    function previewMint(ILeverageToken leverageToken, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory)
    {
        bytes32 mockPreviewMintDataKey = keccak256(abi.encode(leverageToken, equityInCollateralAsset));

        return ActionData({
            collateral: mockPreviewMintData[mockPreviewMintDataKey].collateralToAdd,
            debt: mockPreviewMintData[mockPreviewMintDataKey].debtToBorrow,
            equity: equityInCollateralAsset,
            shares: mockPreviewMintData[mockPreviewMintDataKey].shares,
            tokenFee: mockPreviewMintData[mockPreviewMintDataKey].tokenFee,
            treasuryFee: mockPreviewMintData[mockPreviewMintDataKey].treasuryFee
        });
    }

    function previewWithdraw(ILeverageToken leverageToken, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory)
    {
        bytes32 mockPreviewWithdrawDataKey = keccak256(abi.encode(leverageToken, equityInCollateralAsset));
        return ActionData({
            collateral: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].collateralToRemove,
            debt: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].debtToRepay,
            equity: equityInCollateralAsset,
            shares: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].shares,
            tokenFee: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].tokenFee,
            treasuryFee: mockPreviewWithdrawData[mockPreviewWithdrawDataKey].treasuryFee
        });
    }

    function mint(ILeverageToken leverageToken, uint256 equityInCollateralAsset, uint256 minShares)
        external
        returns (ActionData memory)
    {
        LeverageTokenData storage leverageTokenData = leverageTokens[leverageToken];

        bytes32 mockMintDataKey = keccak256(abi.encode(leverageToken, equityInCollateralAsset, minShares));
        MockMintData[] memory mockMintDataArray = mockMintData[mockMintDataKey];

        // Find the first unexecuted mock mint data
        for (uint256 i = 0; i < mockMintDataArray.length; i++) {
            MockMintData memory _mockMintData = mockMintDataArray[i];
            if (!_mockMintData.isExecuted) {
                // Transfer the required collateral to the LeverageManager
                SafeERC20.safeTransferFrom(
                    leverageTokenData.collateralAsset, msg.sender, address(this), _mockMintData.collateral
                );

                // Give the sender the required debt
                deal(address(leverageTokenData.debtAsset), address(this), _mockMintData.debt);
                leverageTokenData.debtAsset.transfer(msg.sender, _mockMintData.debt);

                // Give the sender the shares
                deal(address(leverageTokenData.leverageToken), address(this), _mockMintData.shares);
                leverageTokenData.leverageToken.transfer(msg.sender, _mockMintData.shares);

                // Set the mock mint data to executed and return the shares minted
                mockMintData[mockMintDataKey][i].isExecuted = true;
                return ActionData({
                    equity: equityInCollateralAsset,
                    collateral: _mockMintData.collateral,
                    debt: _mockMintData.debt,
                    shares: _mockMintData.shares,
                    tokenFee: 0,
                    treasuryFee: 0
                });
            }
        }

        // If no mock mint data is found, revert
        revert("No mock mint data found for MockLeverageManager.mint");
    }

    function withdraw(ILeverageToken leverageToken, uint256 equityInCollateralAsset, uint256 maxShares)
        external
        returns (ActionData memory)
    {
        LeverageTokenData storage leverageTokenData = leverageTokens[leverageToken];

        bytes32 mockWithdrawDataKey = keccak256(abi.encode(leverageToken, equityInCollateralAsset, maxShares));
        MockWithdrawData[] memory mockWithdrawDataArray = mockWithdrawData[mockWithdrawDataKey];

        // Find the first unexecuted mock mint data
        for (uint256 i = 0; i < mockWithdrawDataArray.length; i++) {
            MockWithdrawData memory _mockWithdrawData = mockWithdrawDataArray[i];
            if (!_mockWithdrawData.isExecuted) {
                // Transfer the required debt to the LeverageManager
                SafeERC20.safeTransferFrom(
                    leverageTokenData.debtAsset, msg.sender, address(this), _mockWithdrawData.debt
                );

                // Give the sender the required collateral
                deal(address(leverageTokenData.collateralAsset), address(this), _mockWithdrawData.collateral);
                leverageTokenData.collateralAsset.transfer(msg.sender, _mockWithdrawData.collateral);

                // Burn the sender's shares
                deal(address(leverageTokenData.leverageToken), address(this), _mockWithdrawData.shares);
                leverageTokenData.leverageToken.burn(msg.sender, _mockWithdrawData.shares);

                // Set the mock withdraw data to executed
                mockWithdrawData[mockWithdrawDataKey][i].isExecuted = true;
                return ActionData({
                    equity: equityInCollateralAsset,
                    collateral: _mockWithdrawData.collateral,
                    debt: _mockWithdrawData.debt,
                    shares: _mockWithdrawData.shares,
                    tokenFee: 0,
                    treasuryFee: 0
                });
            }
        }

        // If no mock withdraw data is found, revert
        revert("No mock withdraw data found for MockLeverageManager.withdraw");
    }

    function rebalance(
        ILeverageToken leverageToken,
        RebalanceAction[] calldata actions,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external {
        // Transfer tokens in from caller to this contract
        tokenIn.transferFrom(msg.sender, address(this), amountIn);

        for (uint256 i = 0; i < actions.length; i++) {
            address rebalanceAdapter = getLeverageTokenRebalanceAdapter(leverageToken);

            bool isEligible = IRebalanceAdapter(rebalanceAdapter).isEligibleForRebalance(
                leverageToken, leverageTokenStates[leverageToken], msg.sender
            );
            if (!isEligible) {
                revert("RebalanceAdapter is not eligible for rebalance");
            }
        }

        // Transfer tokens out from this contract to caller
        tokenOut.transfer(msg.sender, amountOut);
    }
}
