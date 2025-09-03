// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IUniswapV2Router02} from "src/interfaces/periphery/IUniswapV2Router02.sol";
import {ActionData} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";

contract LeverageRouterRedeemTest is LeverageRouterTest {
    function testFork_redeem_FullRedeem() public {
        uint256 shares = _deposit();

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        ILeverageRouter.Call[] memory calls = new ILeverageRouter.Call[](2);

        ActionData memory previewData = leverageManager.previewRedeem(leverageToken, shares);
        uint256 collateralForSwap = previewData.collateral * 1.005e18 / 2e18;

        // Approve UniswapV2 to spend the WETH for the swap
        calls[0] = ILeverageRouter.Call({
            target: address(WETH),
            data: abi.encodeWithSelector(IERC20.approve.selector, UNISWAP_V2_ROUTER02, collateralForSwap),
            value: 0
        });
        // Swap WETH to USDC
        calls[1] = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                collateralForSwap,
                0,
                path,
                address(leverageRouter),
                block.timestamp
            ),
            value: 0
        });

        // On chain exact input swap of collateralForSwap using UniswapV2 results in ~6 USDC being left over
        uint256 expectedSurplusDebt = 6.245106e6;

        _redeemAndAssertBalances(shares, 0, calls, expectedSurplusDebt);
    }

    function testFork_redeem_PartialRedeem() public {
        uint256 shares = _deposit();
        uint256 sharesToRedeem = shares / 2;

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(USDC);

        ILeverageRouter.Call[] memory calls = new ILeverageRouter.Call[](2);

        ActionData memory previewData = leverageManager.previewRedeem(leverageToken, sharesToRedeem);
        uint256 collateralForSwap = previewData.collateral * 1.005e18 / 2e18;

        // Approve UniswapV2 to spend the WETH for the swap
        calls[0] = ILeverageRouter.Call({
            target: address(WETH),
            data: abi.encodeWithSelector(IERC20.approve.selector, UNISWAP_V2_ROUTER02, collateralForSwap),
            value: 0
        });
        // Swap WETH to USDC
        calls[1] = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                collateralForSwap,
                0,
                path,
                address(leverageRouter),
                block.timestamp
            ),
            value: 0
        });

        // On chain exact input swap of collateralForSwap using UniswapV2 results in ~3.5 USDC being left over
        uint256 expectedSurplusDebt = 3.538999e6;

        _redeemAndAssertBalances(sharesToRedeem, 0, calls, expectedSurplusDebt);
    }

    function testFork_redeem_LiFi() public {
        vm.rollFork(35069151);
        _deployLeverageRouterIntegrationTestContracts();

        uint256 shares = _deposit();

        ILeverageRouter.Call[] memory calls = new ILeverageRouter.Call[](2);

        ActionData memory previewData = leverageManager.previewRedeem(leverageToken, shares);
        uint256 collateralForSwap = previewData.collateral * 1.004e18 / 2e18;
        assertEq(collateralForSwap, 0.880479727606528588 ether);

        bytes memory sellCalldata =
            hex"5fd9ae2e3d7bac6a4eee4abf5704646f0ef3c1c510c17d8a72bcd3f780b64a52452f787e00000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000756e0562323adcda4430d6cb456d9151f605290b00000000000000000000000000000000000000000000000000000000e7c26d16000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000086c6966692d617069000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a307830303030303030303030303030303030303030303030303030303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000a6d96e7f4d7b96cfe42185df61e64d255c12dff0000000000000000000000000a6d96e7f4d7b96cfe42185df61e64d255c12dff000000000000000000000000420000000000000000000000000000000000000600000000000000000000000042000000000000000000000000000000000000060000000000000000000000000000000000000000000000000c3817a5b3eb7a4c00000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000084eedd56e1000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007d1faa77d6381000000000000000000000000b9c0de368bece5e76b52545a8e377a4c118f597b00000000000000000000000000000000000000000000000000000000000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b750000000000000000000000004200000000000000000000000000000000000006000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000c3045ab0c6e16cb00000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a45f3bd1c800000000000000000000000042000000000000000000000000000000000000060000000000000000000000000000000000000000000000000c3045ab0c6e16cb0000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda0291300000000000000000000000000000000000000000000000000000000e7c26d150000000000000000000000002905d7e4d048d29954f81b02171dd313f457a4a400000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001846be92b8900000000000000000000000042000000000000000000000000000000000000060000000000000000000000000000000000000000000000000c3045ab0c6e16cb000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda0291300000000000000000000000000000000000000000000000000000000ea19b92d0000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004301420000000000000000000000000000000000000601ffff01b2cc224c1c9fee385f8ad6a55b4d94e92359dc59012905d7e4d048d29954f81b02171dd313f457a4a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        calls[0] = ILeverageRouter.Call({
            target: address(WETH),
            data: abi.encodeWithSelector(IERC20.approve.selector, LIFI_DIAMOND, collateralForSwap),
            value: 0
        });
        calls[1] = ILeverageRouter.Call({target: LIFI_DIAMOND, data: sellCalldata, value: 0});

        _redeemAndAssertBalances(shares, 0, calls, 537.37438e6);
    }

    function _deposit() internal returns (uint256 shares) {
        uint256 collateralFromSender = 1 ether;
        uint256 userBalanceOfCollateralAsset = 4 ether;
        uint256 flashLoanAmount = 3382.592531e6;

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ILeverageRouter.Call[] memory calls = new ILeverageRouter.Call[](2);
        // Approve UniswapV2 to spend the USDC for the swap
        calls[0] = ILeverageRouter.Call({
            target: address(USDC),
            data: abi.encodeWithSelector(IERC20.approve.selector, UNISWAP_V2_ROUTER02, flashLoanAmount),
            value: 0
        });
        // Swap USDC to WETH
        calls[1] = ILeverageRouter.Call({
            target: UNISWAP_V2_ROUTER02,
            data: abi.encodeWithSelector(
                IUniswapV2Router02.swapExactTokensForTokens.selector,
                flashLoanAmount,
                0,
                path,
                address(leverageRouter),
                block.timestamp
            ),
            value: 0
        });

        uint256 sharesBefore = leverageToken.balanceOf(user);

        _dealAndDeposit(WETH, USDC, userBalanceOfCollateralAsset, collateralFromSender, flashLoanAmount, 0, calls);

        uint256 sharesAfter = leverageToken.balanceOf(user) - sharesBefore;

        return sharesAfter;
    }

    function _redeemAndAssertBalances(
        uint256 shares,
        uint256 minCollateralForSender,
        ILeverageRouter.Call[] memory swapCalls,
        uint256 expectedDebtForSender
    ) internal {
        uint256 collateralBeforeRedeem = morphoLendingAdapter.getCollateral();
        uint256 debtBeforeRedeem = morphoLendingAdapter.getDebt();
        uint256 userBalanceOfCollateralAssetBeforeRedeem = WETH.balanceOf(user);

        ActionData memory previewData = leverageManager.previewRedeem(leverageToken, shares);

        vm.startPrank(user);
        leverageToken.approve(address(leverageRouter), shares);
        leverageRouter.redeem(leverageToken, shares, minCollateralForSender, swapCalls);
        vm.stopPrank();

        // Check that the periphery contracts don't hold any assets
        assertEq(WETH.balanceOf(address(leverageRouter)), 0);
        assertEq(USDC.balanceOf(address(leverageRouter)), 0);

        // Collateral and debt are removed from the leverage token
        assertEq(morphoLendingAdapter.getCollateral(), collateralBeforeRedeem - previewData.collateral);
        assertEq(morphoLendingAdapter.getDebt(), debtBeforeRedeem - previewData.debt);

        // The user receives back at least the min collateral
        assertGe(WETH.balanceOf(user), userBalanceOfCollateralAssetBeforeRedeem + minCollateralForSender);

        // Validate that user also received the expected debt surplus from the swap
        assertEq(USDC.balanceOf(user), expectedDebtForSender);
    }
}
