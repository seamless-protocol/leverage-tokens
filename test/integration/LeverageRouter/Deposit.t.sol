// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ActionDataV2, LeverageTokenConfig} from "src/types/DataTypes.sol";
import {LeverageRouterTest} from "./LeverageRouter.t.sol";
import {SwapPathLib} from "../../utils/SwapPathLib.sol";
import {MockSwapper} from "../../unit/mock/MockSwapper.sol";

contract LeverageRouterDepositTest is LeverageRouterTest {
    struct DepositWithMockedSwapParams {
        ILeverageToken leverageToken;
        IERC20 collateralAsset;
        IERC20 debtAsset;
        uint256 userBalanceOfCollateralAsset;
        uint256 collateralFromSender;
        uint256 debt;
        uint256 minShares;
        uint256 collateralReceivedFromDebtSwap;
    }

    ILeverageRouter public leverageRouterWithMockSwapAdapter;

    MockSwapper public mockSwapper;

    MorphoLendingAdapter ethShortLendingAdapter;
    RebalanceAdapter ethShortRebalanceAdapter;

    ILeverageToken ethShortLeverageToken;

    function setUp() public override {
        super.setUp();

        mockSwapper = new MockSwapper();

        ethShortRebalanceAdapter =
            _deployRebalanceAdapter(1.3e18, 1.5e18, 2e18, 7 minutes, 1.2e18, 0.9e18, 1.3e18, 45_66);

        ethShortLendingAdapter = MorphoLendingAdapter(
            address(morphoLendingAdapterFactory.deployAdapter(USDC_WETH_MARKET_ID, address(this), bytes32(uint256(1))))
        );

        leverageRouterWithMockSwapAdapter =
            new LeverageRouter(leverageManager, MORPHO, ISwapAdapter(address(mockSwapper)));

        ethShortLeverageToken = leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(ethShortLendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(address(ethShortRebalanceAdapter)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            "Seamless USDC/ETH 2x leverage token",
            "ltUSDC/ETH-2x"
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV2_FirstDeposit() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.997140594716559346e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3382_592531);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit.
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 1.994281188799212725 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // More than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.997140594399606362 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.994290732650270211 ether;
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, collateralFromSender, debtReduced, minShares, swapContext
        );

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user
        uint256 remainingCollateral = collateralFromSender - (collateralRequired - collateralReceivedFromDebtSwap);
        assertEq(remainingCollateral, 0.000009543851057486 ether);

        assertEq(WETH.balanceOf(user), userBalanceOfCollateralAsset - collateralFromSender + remainingCollateral);
        assertEq(
            WETH.balanceOf(user), userBalanceOfCollateralAsset - (collateralRequired - collateralReceivedFromDebtSwap)
        );

        assertGe(leverageToken.balanceOf(user), minShares);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV2_MultipleDeposits() public {
        uint256 userBalanceOfCollateralAsset = 4 ether;
        uint256 collateralFromSender = 1 ether;
        uint256 debtReduced = 3382.592531e6;
        uint256 minShares = 0.997140594252213411 ether;

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(
            WETH, USDC, userBalanceOfCollateralAsset, collateralFromSender, debtReduced, minShares, swapContext
        );

        // Preview data for second deposit
        ActionDataV2 memory previewDataFullDeposit = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
        uint256 collateralReceivedFromDebtSwap = 0.996183258905906079 ether;

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage =
            collateralReceivedFromDebtSwap * 1e18 / (previewDataFullDeposit.collateral - collateralFromSender);
        assertEq(deltaPercentage, 0.996183258611403192e18);
        debtReduced = previewDataFullDeposit.debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3379.344968e6);

        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);

        ActionDataV2 memory previewDataReducedDeposit =
            leverageManager.previewDeposit(leverageToken, collateralRequired);

        // Reverts due to 1 debt asset left over in the LR.
        _dealAndDeposit(
            WETH,
            USDC,
            userBalanceOfCollateralAsset,
            collateralFromSender,
            debtReduced,
            previewDataReducedDeposit.shares,
            swapContext
        );

        previewDataFullDeposit = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
        collateralReceivedFromDebtSwap = 0.995228218648351499 ether;
        deltaPercentage =
            collateralReceivedFromDebtSwap * 1e18 / (previewDataFullDeposit.collateral - collateralFromSender);
        debtReduced = previewDataFullDeposit.debt * deltaPercentage / 1e18;
        collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);
        previewDataReducedDeposit = leverageManager.previewDeposit(leverageToken, collateralRequired);

        _dealAndDeposit(
            WETH,
            USDC,
            userBalanceOfCollateralAsset,
            collateralFromSender,
            debtReduced,
            previewDataReducedDeposit.shares,
            swapContext
        );

        previewDataFullDeposit = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
        collateralReceivedFromDebtSwap = 0.99427546543593209 ether;
        deltaPercentage =
            collateralReceivedFromDebtSwap * 1e18 / (previewDataFullDeposit.collateral - collateralFromSender);
        debtReduced = previewDataFullDeposit.debt * deltaPercentage / 1e18;
        collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + 1;
        previewDataReducedDeposit = leverageManager.previewDeposit(leverageToken, collateralRequired);

        _dealAndDeposit(
            WETH,
            USDC,
            userBalanceOfCollateralAsset,
            collateralFromSender,
            debtReduced,
            previewDataReducedDeposit.shares,
            swapContext
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testForkFuzz_deposit_MultipleDeposits_MockedSwap_CollateralDecimalsGtDebtDecimals(
        uint256 collateralFromSenderA,
        uint256 collateralReceivedFromDebtSwapA,
        uint256 collateralFromSenderB,
        uint256 collateralReceivedFromDebtSwapB,
        uint256 collateralFromSenderC,
        uint256 collateralReceivedFromDebtSwapC
    ) public {
        collateralFromSenderA = bound(collateralFromSenderA, 1, 1000 ether);
        collateralFromSenderB = bound(collateralFromSenderB, 1, 1000 ether);
        collateralFromSenderC = bound(collateralFromSenderC, 1, 1000 ether);

        _supplyUSDCForETHLongLeverageToken(15000000e6);

        ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSenderA);

        collateralReceivedFromDebtSwapA =
            bound(collateralReceivedFromDebtSwapA, 1, previewData.collateral - collateralFromSenderA);

        _depositWithMockedSwap(
            DepositWithMockedSwapParams({
                leverageToken: leverageToken,
                collateralAsset: WETH,
                debtAsset: USDC,
                userBalanceOfCollateralAsset: collateralFromSenderA,
                collateralFromSender: collateralFromSenderA,
                debt: previewData.debt,
                minShares: 0,
                collateralReceivedFromDebtSwap: collateralReceivedFromDebtSwapA
            })
        );

        previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSenderB);

        collateralReceivedFromDebtSwapB =
            bound(collateralReceivedFromDebtSwapB, 1, previewData.collateral - collateralFromSenderB);

        _depositWithMockedSwap(
            DepositWithMockedSwapParams({
                leverageToken: leverageToken,
                collateralAsset: WETH,
                debtAsset: USDC,
                userBalanceOfCollateralAsset: collateralFromSenderB,
                collateralFromSender: collateralFromSenderB,
                debt: previewData.debt,
                minShares: 0,
                collateralReceivedFromDebtSwap: collateralReceivedFromDebtSwapB
            })
        );

        previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSenderC);

        collateralReceivedFromDebtSwapC =
            bound(collateralReceivedFromDebtSwapC, 1, previewData.collateral - collateralFromSenderC);

        _depositWithMockedSwap(
            DepositWithMockedSwapParams({
                leverageToken: leverageToken,
                collateralAsset: WETH,
                debtAsset: USDC,
                userBalanceOfCollateralAsset: collateralFromSenderC,
                collateralFromSender: collateralFromSenderC,
                debt: previewData.debt,
                minShares: 0,
                collateralReceivedFromDebtSwap: collateralReceivedFromDebtSwapC
            })
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testForkFuzz_deposit_MultipleDeposits_MockedSwap_DebtDecimalsGtCollateralDecimals(
        uint256 collateralFromSenderA,
        uint256 collateralReceivedFromDebtSwapA,
        uint256 collateralFromSenderB,
        uint256 collateralReceivedFromDebtSwapB,
        uint256 collateralFromSenderC,
        uint256 collateralReceivedFromDebtSwapC
    ) public {
        collateralFromSenderA = bound(collateralFromSenderA, 1, 3000000e6);
        collateralFromSenderB = bound(collateralFromSenderB, 1, 3000000e6);
        collateralFromSenderC = bound(collateralFromSenderC, 1, 3000000e6);

        _supplyWETHForETHShortLeverageToken(6000 ether);

        ActionDataV2 memory previewData = leverageRouter.previewDeposit(ethShortLeverageToken, collateralFromSenderA);

        collateralReceivedFromDebtSwapA =
            bound(collateralReceivedFromDebtSwapA, 1, previewData.collateral - collateralFromSenderA);

        _depositWithMockedSwap(
            DepositWithMockedSwapParams({
                leverageToken: ethShortLeverageToken,
                collateralAsset: USDC,
                debtAsset: WETH,
                userBalanceOfCollateralAsset: collateralFromSenderA,
                collateralFromSender: collateralFromSenderA,
                debt: previewData.debt,
                minShares: 0,
                collateralReceivedFromDebtSwap: collateralReceivedFromDebtSwapA
            })
        );

        previewData = leverageRouter.previewDeposit(ethShortLeverageToken, collateralFromSenderB);

        collateralReceivedFromDebtSwapB =
            bound(collateralReceivedFromDebtSwapB, 1, previewData.collateral - collateralFromSenderB);

        _depositWithMockedSwap(
            DepositWithMockedSwapParams({
                leverageToken: ethShortLeverageToken,
                collateralAsset: USDC,
                debtAsset: WETH,
                userBalanceOfCollateralAsset: collateralFromSenderB,
                collateralFromSender: collateralFromSenderB,
                debt: previewData.debt,
                minShares: 0,
                collateralReceivedFromDebtSwap: collateralReceivedFromDebtSwapB
            })
        );

        previewData = leverageRouter.previewDeposit(ethShortLeverageToken, collateralFromSenderC);

        collateralReceivedFromDebtSwapC =
            bound(collateralReceivedFromDebtSwapC, 1, previewData.collateral - collateralFromSenderC);

        _depositWithMockedSwap(
            DepositWithMockedSwapParams({
                leverageToken: ethShortLeverageToken,
                collateralAsset: USDC,
                debtAsset: WETH,
                userBalanceOfCollateralAsset: collateralFromSenderC,
                collateralFromSender: collateralFromSenderC,
                debt: previewData.debt,
                minShares: 0,
                collateralReceivedFromDebtSwap: collateralReceivedFromDebtSwapC
            })
        );
    }

    function _depositWithMockedSwap(DepositWithMockedSwapParams memory params) internal {
        uint256 collateralToAdd =
            leverageRouter.previewDeposit(params.leverageToken, params.collateralFromSender).collateral;

        uint256 debtReduced = params.debt;
        if (params.collateralReceivedFromDebtSwap < collateralToAdd - params.collateralFromSender) {
            // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
            // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
            uint256 deltaPercentage =
                params.collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - params.collateralFromSender);
            debtReduced = params.debt * deltaPercentage / 1e18;
        }

        if (debtReduced == 0) {
            return;
        }

        {
            uint256 collateralRequired =
                leverageManager.convertDebtToCollateral(params.leverageToken, debtReduced, Math.Rounding.Ceil);

            // When the total supply of the LT is zero, we need to add the buffer applied onto the required collateral to accommodate for rounding asymmetry
            ILendingAdapter _lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(params.leverageToken);
            if (_lendingAdapter.getCollateral() == 0 && _lendingAdapter.getDebt() == 0) {
                collateralRequired += _lendingAdapter.convertDebtToCollateralAsset(1);
            }

            assertGe(leverageManager.previewDeposit(params.leverageToken, collateralRequired).debt, debtReduced);
            // Mock the swap of the debt asset to the collateral asset to be the required amount
            uint256 collateralReceivedFromReducedDebtSwap =
                collateralRequired > params.collateralFromSender ? collateralRequired - params.collateralFromSender : 0;
            mockSwapper.mockNextExactInputSwap(
                params.debtAsset, params.collateralAsset, collateralReceivedFromReducedDebtSwap
            );
        }

        {
            address[] memory path = new address[](2);
            path[0] = address(params.debtAsset);
            path[1] = address(params.collateralAsset);

            ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
                exchange: ISwapAdapter.Exchange.UNISWAP_V2,
                encodedPath: new bytes(0),
                path: path,
                fees: new uint24[](0),
                tickSpacing: new int24[](0),
                exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                    aerodromeRouter: address(0),
                    aerodromePoolFactory: address(0),
                    aerodromeSlipstreamRouter: address(0),
                    uniswapSwapRouter02: address(0),
                    uniswapV2Router02: UNISWAP_V2_ROUTER02
                }),
                additionalData: new bytes(0)
            });

            deal(address(params.collateralAsset), user, params.userBalanceOfCollateralAsset);

            vm.startPrank(user);
            params.collateralAsset.approve(address(leverageRouterWithMockSwapAdapter), params.collateralFromSender);
            leverageRouterWithMockSwapAdapter.deposit(
                params.leverageToken, params.collateralFromSender, debtReduced, params.minShares, swapContext
            );
            vm.stopPrank();
        }

        assertEq(params.collateralAsset.balanceOf(address(leverageRouterWithMockSwapAdapter)), 0);
        assertEq(params.debtAsset.balanceOf(address(leverageRouterWithMockSwapAdapter)), 0);
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_ExceedsSlippage() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 sharesFromDeposit = 1 ether;
        uint256 minShares = sharesFromDeposit * 0.99715e18 / 1e18; // 0.285% slippage
        uint256 collateralReceivedFromDebtSwap = 0.997140594716559346 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, sharesFromDeposit);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.997140594716559346e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3382_592531);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 1.994281188799212725 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // Less than minShares (0.01% slippage) will be minted
            assertLt(previewData.shares, minShares);
            assertEq(previewData.shares, 0.997140594399606362 ether);

            // The slippage is greater than 0.01%
            uint256 actualSlippage = 1e18 - previewData.shares * 1e18 / sharesFromDeposit;
            assertEq(actualSlippage, 0.002859405600393638e18); // ~0.286% slippage

            // Sanity check: previewMint results in the same collateral and debt amounts
            previewData = leverageManager.previewMintV2(leverageToken, previewData.shares);
            assertEq(previewData.collateral, collateralRequired - 1); // -1 to accommodate for the buffer added
            assertEq(previewData.debt, debtReduced);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.994290732650270211 ether;
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        deal(address(WETH), user, userBalanceOfCollateralAsset);
        vm.startPrank(user);
        WETH.approve(address(leverageRouter), collateralFromSender);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, 0.997140594399606362 ether, 0.99715 ether)
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, debtReduced, minShares, swapContext);
        vm.stopPrank();
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_InsufficientCollateralForDeposit() public {
        uint256 collateralFromSender = 0.01 ether;

        uint256 collateralFromSenderInDebt = morphoLendingAdapter.convertCollateralToDebtAsset(collateralFromSender);
        assertEq(collateralFromSenderInDebt, 33.922924e6);
        // Slightly less when converting back to collateral due to precision loss
        assertEq(
            morphoLendingAdapter.convertDebtToCollateralAsset(collateralFromSenderInDebt), 0.009999999788958522 ether
        );

        // 2x collateral ratio
        ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
        assertEq(previewData.collateral, collateralFromSender * 2);
        assertEq(previewData.debt, collateralFromSenderInDebt);

        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, previewData.debt, Math.Rounding.Ceil);
        collateralRequired += morphoLendingAdapter.convertDebtToCollateralAsset(1);
        assertEq(collateralRequired, 0.019999999872702948 ether);

        // Preview again using the new collateral required; results in the same debt amount
        assertEq(leverageManager.previewDeposit(leverageToken, collateralRequired).debt, previewData.debt);

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        // The collateral received from swapping 33.922924e6 USDC is 0.009976155542446272 WETH in this block using Uniswap V2
        uint256 collateralReceivedFromDebtSwap = 0.009976155542446272 ether;

        // The collateral from the swap + the collateral from the sender is less than the collateral required
        uint256 totalCollateral = collateralReceivedFromDebtSwap + collateralFromSender;
        assertLt(totalCollateral, collateralRequired);

        deal(address(WETH), user, collateralFromSender);
        vm.startPrank(user);
        WETH.approve(address(leverageRouter), collateralFromSender);

        // Reverts due to insufficient collateral from swap + user for the deposit
        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageRouter.InsufficientCollateralForDeposit.selector, totalCollateral, collateralRequired
            )
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, previewData.debt, 0, swapContext);
        vm.stopPrank();

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage =
            collateralReceivedFromDebtSwap * 1e18 / (collateralFromSender * 2 - collateralFromSender);
        assertEq(deltaPercentage, 0.9976155542446272e18);
        uint256 debtReduced = previewData.debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 33.842036e6);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil);
        collateralRequired += morphoLendingAdapter.convertDebtToCollateralAsset(1);
        assertEq(collateralRequired, 0.019952310588434335 ether);

        // Sanity check: preview again using the new collateral required. This is used by the LM deposit logic
        previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
        assertEq(previewData.debt, debtReduced);

        // Sanity check: previewMint results in the same collateral and debt amounts
        previewData = leverageManager.previewMintV2(leverageToken, previewData.shares);
        assertEq(previewData.collateral, collateralRequired - 1); // -1 to accommodate for the buffer added
        assertEq(previewData.debt, debtReduced);

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debtReduced, 0, swapContext);
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV3() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.999899417781964728 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.999899417781964728e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3391_951266);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 1.999798835097917325 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // More than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.999899417548958662 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.999798847238411671 ether;
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            encodedPath: SwapPathLib._encodeUniswapV3Path(path, fees, false),
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: UNISWAP_SWAP_ROUTER02,
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debtReduced, minShares, swapContext);

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user
        uint256 remainingCollateral = collateralFromSender - (collateralRequired - collateralReceivedFromDebtSwap);
        assertEq(remainingCollateral, 0.000000012140494346 ether);

        assertEq(WETH.balanceOf(user), remainingCollateral);

        assertGe(leverageToken.balanceOf(user), minShares);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_Aerodrome() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.99780113268167845 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.99780113268167845e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3384_833269);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 1.99560226474933491 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // More than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.997801132374667455 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.995607717905650985 ether;
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: AERODROME_ROUTER,
                aerodromePoolFactory: AERODROME_POOL_FACTORY,
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debtReduced, minShares, swapContext);

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user
        uint256 remainingCollateral = collateralFromSender - (collateralRequired - collateralReceivedFromDebtSwap);
        assertEq(remainingCollateral, 0.000005453156316075 ether);

        assertEq(WETH.balanceOf(user), remainingCollateral);

        assertGe(leverageToken.balanceOf(user), minShares);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_AerodromeSlipstream() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage

        // Swap is favorable with slipstream, results in more than required collateral
        uint256 collateralReceivedFromDebtSwap = 1.00009355883189593 ether; // Swap of 3392.292471 USDC

        uint256 collateralRequired = leverageManager.convertDebtToCollateral(leverageToken, debt, Math.Rounding.Ceil);
        collateralRequired += morphoLendingAdapter.convertDebtToCollateralAsset(1);
        assertGt(collateralFromSender + collateralReceivedFromDebtSwap, collateralRequired);

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 100;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
            encodedPath: SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, false),
            path: path,
            fees: new uint24[](0),
            tickSpacing: tickSpacing,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: AERODROME_SLIPSTREAM_ROUTER,
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debt, minShares, swapContext);

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user.
        uint256 remainingCollateral = collateralReceivedFromDebtSwap + collateralFromSender - collateralRequired;
        assertEq(remainingCollateral, 0.000093558885807404 ether);

        assertEq(WETH.balanceOf(user), remainingCollateral);

        assertGe(leverageToken.balanceOf(user), minShares);
        assertEq(leverageToken.balanceOf(user), 0.999999999973044263 ether);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debt + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV2_MultiHop() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 userBalanceOfCollateralAsset = 4 ether; // User has more than enough assets for the mint of equity
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.003436017464761568 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.003436017464761568e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 11_655976);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit.
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 0.006872035119384491 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // Less than minShares (1% slippage) will be minted
            assertLt(previewData.shares, minShares);
            assertEq(previewData.shares, 0.003436017559692245 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.001720627030031886 ether;
        }

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(DAI);
        path[2] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: UNISWAP_V2_ROUTER02
            }),
            additionalData: new bytes(0)
        });

        deal(address(WETH), user, userBalanceOfCollateralAsset);
        vm.startPrank(user);
        WETH.approve(address(leverageRouter), collateralFromSender);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, 0.003436017559692245 ether, minShares)
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, debtReduced, minShares, swapContext);
        vm.stopPrank();
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_UniswapV3_MultiHop() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.73e18 / 1e18; // 27% slippage
        uint256 collateralReceivedFromDebtSwap = 0.730785046551638276 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.730785046551638276e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 2479_036611);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 1.461570092944844565 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // More than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.730785046472422282 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.719360769453766291 ether;
        }

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(DAI);
        path[2] = address(WETH);

        uint24[] memory fees = new uint24[](2);
        fees[0] = 500;
        fees[1] = 500;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            encodedPath: SwapPathLib._encodeUniswapV3Path(path, fees, false),
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: UNISWAP_SWAP_ROUTER02,
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debtReduced, minShares, swapContext);

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user
        uint256 remainingCollateral = collateralFromSender - (collateralRequired - collateralReceivedFromDebtSwap);
        assertEq(remainingCollateral, 0.257790676508921726 ether);
        assertEq(WETH.balanceOf(user), remainingCollateral);

        assertGe(leverageToken.balanceOf(user), minShares);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_Aerodrome_MultiHop() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.001479490022113963 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.001479490022113963e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 5_018862);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 0.002958979829734716 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // Less than minShares (1% slippage) will be minted
            assertLt(previewData.shares, minShares);
            assertEq(previewData.shares, 0.001479489914867358 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.000737563974906262 ether;
        }

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(DAI);
        path[2] = address(WETH);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            encodedPath: new bytes(0),
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: AERODROME_ROUTER,
                aerodromePoolFactory: AERODROME_POOL_FACTORY,
                aerodromeSlipstreamRouter: address(0),
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        deal(address(WETH), user, collateralFromSender);
        vm.startPrank(user);
        WETH.approve(address(leverageRouter), collateralFromSender);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, 0.001479489914867358 ether, minShares)
        );
        leverageRouter.deposit(leverageToken, collateralFromSender, debtReduced, minShares, swapContext);
        vm.stopPrank();
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_AerodromeSlipstream_MultiHop() public {
        uint256 collateralFromSender = 1 ether;
        uint256 collateralToAdd = 2 * collateralFromSender;
        uint256 debt = 3392_292471; // 3392.292471 USDC
        uint256 minShares = 1 ether * 0.99e18 / 1e18; // 1% slippage
        uint256 collateralReceivedFromDebtSwap = 0.999075127525769712 ether; // Swap of 3392.292471 USDC

        {
            // Sanity check that LR preview deposit matches test params
            ActionDataV2 memory previewData = leverageRouter.previewDeposit(leverageToken, collateralFromSender);
            assertEq(previewData.debt, debt);
            assertEq(previewData.shares, 1 ether);
            assertEq(previewData.collateral, collateralToAdd);
            assertEq(previewData.tokenFee, 0);
            assertEq(previewData.treasuryFee, 0);
        }

        // The swap results in less collateral than required to get the flash loaned debt amount from a LM deposit, so the debt amount flash loaned
        // needs to be reduced. We reduce it by the percentage delta between the required collateral and the collateral received from the swap
        uint256 deltaPercentage = collateralReceivedFromDebtSwap * 1e18 / (collateralToAdd - collateralFromSender);
        assertEq(deltaPercentage, 0.999075127525769712e18);
        uint256 debtReduced = debt * deltaPercentage / 1e18;
        assertEq(debtReduced, 3389_155033);

        // Preview the amount of collateral required to get the flash loaned debt amount from a LM deposit
        // A buffer is added to accommodate for rounding asymmetry between convertDebtToCollateral and convertCollateralToDebt when the LT has no
        // collateral or debt (used in the LM deposit logic)
        uint256 buffer = morphoLendingAdapter.convertDebtToCollateralAsset(1);
        uint256 collateralRequired =
            leverageManager.convertDebtToCollateral(leverageToken, debtReduced, Math.Rounding.Ceil) + buffer;
        assertEq(collateralRequired, 1.998150254957250273 ether);

        {
            // Preview again using the new collateral required. This is used by the LM deposit logic
            ActionDataV2 memory previewData = leverageManager.previewDeposit(leverageToken, collateralRequired);
            assertEq(previewData.debt, debtReduced);

            // Less than minShares (1% slippage) will be minted
            assertGe(previewData.shares, minShares);
            assertEq(previewData.shares, 0.999075127478625136 ether);

            // Updated collateral received from the debt swap for lower debt amount
            collateralReceivedFromDebtSwap = 0.998151321850066641 ether;
        }

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = address(cbBTC);
        path[2] = address(WETH);

        int24[] memory tickSpacing = new int24[](2);
        tickSpacing[0] = 100;
        tickSpacing[1] = 100;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
            encodedPath: SwapPathLib._encodeAerodromeSlipstreamPath(path, tickSpacing, false),
            path: path,
            fees: new uint24[](0),
            tickSpacing: tickSpacing,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromePoolFactory: address(0),
                aerodromeSlipstreamRouter: AERODROME_SLIPSTREAM_ROUTER,
                uniswapSwapRouter02: address(0),
                uniswapV2Router02: address(0)
            }),
            additionalData: new bytes(0)
        });

        _dealAndDeposit(WETH, USDC, collateralFromSender, collateralFromSender, debtReduced, minShares, swapContext);

        // Collateral is taken from the user for the mint. Any remaining collateral is returned to the user.
        uint256 remainingCollateral = collateralReceivedFromDebtSwap + collateralFromSender - collateralRequired;
        assertEq(remainingCollateral, 0.000001066892816368 ether);

        assertEq(WETH.balanceOf(user), remainingCollateral);

        assertGe(leverageToken.balanceOf(user), minShares);
        assertEq(leverageToken.balanceOf(user), 0.999075127478625136 ether);

        assertEq(morphoLendingAdapter.getCollateral(), collateralRequired);
        assertEq(morphoLendingAdapter.getDebt(), debtReduced + 1); // + 1 because of rounding up by MorphoBalancesLib.expectedBorrowAssets
    }

    function test_convertEquivalence_DebtFromCollateralGreaterThanInitialDebt() public pure {
        uint256 debt = 1000;
        uint256 totalDebt = 33333;
        uint256 totalCollateral = 10000;

        // Used to get collateral amount to deposit for debt flash loaned in LR deposit logic
        uint256 collateralFromDebt = Math.mulDiv(debt, totalCollateral, totalDebt, Math.Rounding.Ceil);

        // Used to get debt required for deposit in LM.previewDeposit, used by LM.deposit
        uint256 debtFromCollateral = Math.mulDiv(collateralFromDebt, totalDebt, totalCollateral, Math.Rounding.Floor);

        assertFalse(debtFromCollateral == debt);
        assertEq(debtFromCollateral, 1003);
    }

    function testFuzz_convertEquivalence_DebtFromCollateralGreaterThanOrEqualToInitialDebt(
        uint256 debt,
        uint256 totalDebt,
        uint256 totalCollateral
    ) public pure {
        totalCollateral = bound(totalCollateral, 1, type(uint128).max);
        debt = bound(debt, 1, type(uint256).max / totalCollateral);
        totalDebt = bound(totalDebt, 1, type(uint256).max / (debt * totalCollateral));

        // Used to get collateral amount to deposit for debt flash loaned in LR deposit logic
        uint256 collateralFromDebt = Math.mulDiv(debt, totalCollateral, totalDebt, Math.Rounding.Ceil);

        // Used to get debt required for deposit in LM.previewDeposit, used by LM.deposit
        uint256 debtFromCollateral = Math.mulDiv(collateralFromDebt, totalDebt, totalCollateral, Math.Rounding.Floor);

        assertGe(debtFromCollateral, debt, "debtFromCollateral should be greater than or equal to debt");
    }

    function _supplyWETHForETHShortLeverageToken(uint256 amount) internal {
        deal(address(WETH), address(this), amount);
        IMorpho morpho = IMorpho(ethShortLendingAdapter.morpho());

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            ethShortLendingAdapter.marketParams();
        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        WETH.approve(address(morpho), amount);
        morpho.supply(marketParams, amount, 0, address(this), new bytes(0));
    }

    function _supplyUSDCForETHLongLeverageToken(uint256 amount) internal {
        deal(address(USDC), address(this), amount);
        IMorpho morpho = IMorpho(morphoLendingAdapter.morpho());

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            morphoLendingAdapter.marketParams();
        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        USDC.approve(address(morpho), amount);
        morpho.supply(marketParams, amount, 0, address(morphoLendingAdapter), new bytes(0));
    }
}
