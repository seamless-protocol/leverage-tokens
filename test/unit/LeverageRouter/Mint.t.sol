// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";

contract MintTest is LeverageRouterTest {
    function testFuzz_mint_DebtSwapLessThanRequiredFlashLoanRepaymentCollateral_SenderSuppliesSufficientCollateral(
        uint256 requiredCollateral,
        uint256 equityInCollateralAsset,
        uint256 collateralReceivedFromDebtSwap,
        uint256 collateralFromSender
    ) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint128).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the mint
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        // The required flash loan is the required collateral minus the equity being minted
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mock collateral received from the debt swap to be less than the required flash loan repayment
        collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, 0, requiredFlashLoan - 1);
        // The delta between the required flash loan repayment and the collateral received from the debt swap is the additional collateral
        // required to cover the flash loan repayment
        uint256 additionalCollateralRequiredForFlashLoanRepay = requiredFlashLoan - collateralReceivedFromDebtSwap;
        // User approves at minimum an amount of collateral to cover the equity plus the additional collateral to help with flash loan repayment.
        // We bound the max to avoid overflows when adding the collateral from the sender to the collateral from the debt swap
        collateralFromSender = bound(
            collateralFromSender,
            equityInCollateralAsset + additionalCollateralRequiredForFlashLoanRepay,
            type(uint256).max - collateralReceivedFromDebtSwap
        );

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        /// Mocked debt required to mint the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerMint(
            requiredCollateral, equityInCollateralAsset, requiredDebt, collateralReceivedFromDebtSwap, shares
        );

        // Execute the mint
        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);
        leverageRouter.mint(
            leverageToken,
            equityInCollateralAsset,
            shares,
            additionalCollateralRequiredForFlashLoanRepay,
            // Mock the swap context (doesn't matter for this test as the swap is mocked)
            ISwapAdapter.SwapContext({
                path: new address[](0),
                encodedPath: new bytes(0),
                fees: new uint24[](0),
                tickSpacing: new int24[](0),
                exchange: ISwapAdapter.Exchange.AERODROME,
                exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                    aerodromeRouter: address(0),
                    aerodromePoolFactory: address(0),
                    aerodromeSlipstreamRouter: address(0),
                    uniswapSwapRouter02: address(0),
                    uniswapV2Router02: address(0)
                })
            })
        );

        // Sender receives the minted shares
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(leverageToken.balanceOf(address(leverageRouter)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

        // Sender's assets are used for the equity and to help repay the flash loan
        assertEq(
            collateralToken.balanceOf(address(this)),
            collateralFromSender - (equityInCollateralAsset + additionalCollateralRequiredForFlashLoanRepay)
        );
    }

    function testFuzz_mint_DebtSwapGteRequiredFlashLoanRepaymentCollateral(
        uint256 requiredCollateral,
        uint256 equityInCollateralAsset,
        uint256 collateralReceivedFromDebtSwap
    ) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint256).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the mint
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        // LeverageRouter will flash loan the required collateral minus the equity being minted
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mock collateral received from the debt swap to be >= the required flash loan repayment
        collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, requiredFlashLoan, type(uint256).max);
        // Sender does not need to send any additional collateral to help repay the flash loan, as the debt swap results in enough collateral
        // to repay the flash loan
        uint256 requiredCollateralFromSender = equityInCollateralAsset;

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        /// Mocked debt required to mint the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerMint(
            requiredCollateral, equityInCollateralAsset, requiredDebt, collateralReceivedFromDebtSwap, shares
        );

        // Execute the mint
        deal(address(collateralToken), address(this), requiredCollateralFromSender);
        collateralToken.approve(address(leverageRouter), requiredCollateralFromSender);
        leverageRouter.mint(
            leverageToken,
            equityInCollateralAsset,
            shares,
            0, // Sender does not need to send any additional collateral to help repay the flash loan
            // Mock the swap context (doesn't matter for this test as the swap is mocked)
            ISwapAdapter.SwapContext({
                path: new address[](0),
                encodedPath: new bytes(0),
                fees: new uint24[](0),
                tickSpacing: new int24[](0),
                exchange: ISwapAdapter.Exchange.AERODROME,
                exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                    aerodromeRouter: address(0),
                    aerodromePoolFactory: address(0),
                    aerodromeSlipstreamRouter: address(0),
                    uniswapSwapRouter02: address(0),
                    uniswapV2Router02: address(0)
                })
            })
        );

        // Sender receives the minted shares
        assertEq(leverageToken.balanceOf(address(this)), shares);
        assertEq(leverageToken.balanceOf(address(leverageRouter)), 0);

        // The LeverageRouter has the required collateral to repay the flash loan and Morpho is approved to spend it
        assertEq(collateralToken.balanceOf(address(leverageRouter)), requiredFlashLoan);
        assertEq(collateralToken.allowance(address(leverageRouter), address(morpho)), requiredFlashLoan);

        // Sender receives any surplus collateral asset leftover after the flash loan is repaid, due to the debt swap being favorable
        assertEq(
            collateralToken.balanceOf(address(this)),
            collateralReceivedFromDebtSwap > requiredFlashLoan ? collateralReceivedFromDebtSwap - requiredFlashLoan : 0
        );
    }

    function testFuzz_mint_RevertIf_MaxSwapCostExceeded(
        uint256 requiredCollateral,
        uint256 equityInCollateralAsset,
        uint256 collateralReceivedFromDebtSwap,
        uint256 collateralFromSender
    ) public {
        requiredCollateral = bound(requiredCollateral, 1, type(uint128).max);
        // Ensure that a flash loan is required by making equity less than the required collateral for the mint
        equityInCollateralAsset = requiredCollateral > 1 ? bound(equityInCollateralAsset, 1, requiredCollateral - 1) : 0;

        // LeverageRouter will flash loan the required collateral minus the equity being minted
        uint256 requiredFlashLoan = requiredCollateral - equityInCollateralAsset;
        // Mock collateral received from the debt swap to be less than the required flash loan repayment
        collateralReceivedFromDebtSwap = bound(collateralReceivedFromDebtSwap, 0, requiredFlashLoan - 1);
        // The delta between the required flash loan repayment and the collateral received from the debt swap is the additional collateral
        // required to cover the flash loan
        uint256 additionalCollateralRequiredForFlashLoan = requiredFlashLoan - collateralReceivedFromDebtSwap;
        // User does not approve enough collateral to cover the additional collateral to help with flash loan repayment. We bound the max
        // to avoid overflows when adding the collateral from the sender to the collateral from the debt swap
        collateralFromSender = bound(
            collateralFromSender,
            equityInCollateralAsset,
            equityInCollateralAsset + additionalCollateralRequiredForFlashLoan - 1
        );

        // Mocked exchange rate of shares (Doesn't matter for this test as the shares received and previewed are mocked)
        uint256 shares = 10 ether;
        /// Mocked debt required to mint the equity (Doesn't matter for this test as the debt swap is mocked)
        uint256 requiredDebt = 100e6;

        _mockLeverageManagerMint(
            requiredCollateral, equityInCollateralAsset, requiredDebt, collateralReceivedFromDebtSwap, shares
        );

        // Execute the mint
        deal(address(collateralToken), address(this), collateralFromSender);
        collateralToken.approve(address(leverageRouter), collateralFromSender);
        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageRouter.MaxSwapCostExceeded.selector,
                additionalCollateralRequiredForFlashLoan,
                collateralFromSender - equityInCollateralAsset
            )
        );
        leverageRouter.mint(
            leverageToken,
            equityInCollateralAsset,
            shares,
            collateralFromSender - equityInCollateralAsset,
            // Mock the swap context (doesn't matter for this test as the swap is mocked)
            ISwapAdapter.SwapContext({
                path: new address[](0),
                encodedPath: new bytes(0),
                fees: new uint24[](0),
                tickSpacing: new int24[](0),
                exchange: ISwapAdapter.Exchange.AERODROME,
                exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                    aerodromeRouter: address(0),
                    aerodromePoolFactory: address(0),
                    aerodromeSlipstreamRouter: address(0),
                    uniswapSwapRouter02: address(0),
                    uniswapV2Router02: address(0)
                })
            })
        );
    }
}
