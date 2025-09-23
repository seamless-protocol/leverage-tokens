// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// Dependency imports
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {LeverageTokenState, RebalanceAction, ActionType, LeverageTokenConfig} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {LeverageManagerTest} from "../LeverageManager/LeverageManager.t.sol";

enum RebalanceType {
    UP,
    DOWN
}

contract RebalanceTest is LeverageManagerTest {
    int256 public constant MAX_PERCENTAGE = 100_00; // 100%

    function setUp() public virtual override {
        super.setUp();

        rebalanceAdapterImplementation = new RebalanceAdapter();
        rebalanceAdapter = _deployRebalanceAdapter(1.8e18, 2e18, 2.2e18, 7 minutes, 1.2e18, 0.98e18, 1.3e18, 45_66);

        morphoLendingAdapter = MorphoLendingAdapter(
            address(morphoLendingAdapterFactory.deployAdapter(CBBTC_USDC_MARKET_ID, address(this), bytes32(uint256(1))))
        );

        leverageToken = leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(morphoLendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(rebalanceAdapter),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            "Seamless CBBTC/USDC 2x leverage token",
            "ltCBBTC/USDC-2x"
        );
    }

    function test_rebalance_SingleLeverageToken_OverCollateralized() public {
        _mint();

        // After previous action we expect leverage token to have 1 cbBTC collateral
        // We need to mock price change so leverage token goes off balance
        // Price should change for 20% which means that collateral ratio is now going to be ~2.4x
        _moveBTCPrice(20_00);

        LeverageTokenState memory stateBefore = getLeverageTokenState(leverageToken);
        assertEq(stateBefore.collateralRatio, 2.399999999978076652e18);

        uint256 collateralBefore = morphoLendingAdapter.getCollateral();
        assertEq(collateralBefore, 1e8);
        uint256 debtBefore = morphoLendingAdapter.getDebt();
        assertEq(debtBefore, 54736.165348e6);

        // At the moment we have the following state:
        // 1 cbBTC collateral = 131366.796834 USDC debt
        // 54736.165348 USDC debt is owed to the Morpho protocol

        // User rebalances the leverage token but still leaves it out of bounds
        // User adds 1 cbBTC collateral and borrows 60000 USDC
        _rebalance(leverageToken, RebalanceType.UP, 1e8, 0, 60000e6, 0);

        // Validate that ratio is better (leans towards 2x)
        LeverageTokenState memory stateAfter = getLeverageTokenState(leverageToken);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertGe(stateAfter.collateralRatio, 2 * BASE_RATIO);

        uint256 collateralAfter = morphoLendingAdapter.getCollateral();
        uint256 debtAfter = morphoLendingAdapter.getDebt();

        // Check that collateral and debt are changed properly
        assertEq(collateralAfter, collateralBefore + 1e8);
        assertEq(debtAfter, debtBefore + 60000e6);

        // Check that USDC is sent to rebalancer and that cbBTC is taken from the rebalancer
        assertEq(USDC.balanceOf(address(rebalanceAdapter)), 60000e6);
        assertEq(CBBTC.balanceOf(address(rebalanceAdapter)), 0);
    }

    function test_rebalance_SingleLeverageToken_UnderCollateralized() public {
        _mint();

        // After previous action we expect leverage token to have 1 cbBTC collateral
        // We need to mock price change so leverage token goes off balance
        // Price should change for 20% downwards which means that collateral ratio is now going to be ~1.6x
        _moveBTCPrice(-20_00);

        LeverageTokenState memory stateBefore = getLeverageTokenState(leverageToken);
        assertEq(stateBefore.collateralRatio, 1.599999999985384434e18);

        uint256 collateralBefore = morphoLendingAdapter.getCollateral();
        assertEq(collateralBefore, 1e8);
        uint256 debtBefore = morphoLendingAdapter.getDebt();
        assertEq(debtBefore, 54736.165348e6);

        // User repays 5400 USDC and removes 0.05 cbBTC collateral
        _rebalance(leverageToken, RebalanceType.DOWN, 0, 0.05e8, 0, 5400e6);

        // Validate that ratio is better (leans towards 2x)
        LeverageTokenState memory stateAfter = getLeverageTokenState(leverageToken);
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, 2 * BASE_RATIO);

        uint256 collateralAfter = morphoLendingAdapter.getCollateral();
        uint256 debtAfter = morphoLendingAdapter.getDebt();

        // Check that collateral and debt are changed properly
        assertEq(collateralAfter, collateralBefore - 0.05e8);
        assertEq(debtAfter, debtBefore - 5400e6);

        // Check that USDC is sent to rebalancer and that cbBTC is taken from the rebalancer
        assertEq(USDC.balanceOf(address(rebalanceAdapter)), 0);
        assertEq(CBBTC.balanceOf(address(rebalanceAdapter)), 0.05e8);
    }

    function test_rebalance_RevertIf_ExposureDirectionChanged() public {
        _mint();

        // Move price of cbBTC 20% downwards
        _moveBTCPrice(-20_00);

        // User comes and rebalances by only adding collateral so the leverage token becomes over-collateralized
        (RebalanceAction[] memory actions, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOut) =
            _prepareForRebalance(leverageToken, RebalanceType.UP, 0.5e8, 0, 0, 0);

        vm.prank(address(rebalanceAdapter));
        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.InvalidLeverageTokenStateAfterRebalance.selector, leverageToken)
        );
        leverageManager.rebalance(leverageToken, actions, tokenIn, tokenOut, amountIn, amountOut);
    }

    struct RebalanceData {
        uint256 collateralToAdd;
        uint256 collateralToRemove;
        uint256 debtToBorrow;
        uint256 debtToRepay;
    }

    /// @notice Prepares rebalance parameters and executes rebalance
    /// @param leverageToken LeverageToken to rebalance
    /// @param collToAdd Amount of collateral to add
    /// @param collToTake Amount of collateral to remove
    /// @param debtToBorrow Amount of debt to borrow
    /// @param debtToRepay Amount of debt to repay
    function _rebalance(
        ILeverageToken leverageToken,
        RebalanceType rebalanceType,
        uint256 collToAdd,
        uint256 collToTake,
        uint256 debtToBorrow,
        uint256 debtToRepay
    ) internal {
        (RebalanceAction[] memory actions, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOut) =
            _prepareForRebalance(leverageToken, rebalanceType, collToAdd, collToTake, debtToBorrow, debtToRepay);

        vm.prank(address(rebalanceAdapter));
        leverageManager.rebalance(leverageToken, actions, tokenIn, tokenOut, amountIn, amountOut);
    }

    /// @notice Prepares the state for the rebalance which means prepares the parameters for function call but also mint tokens to rebalancer
    /// @param leverageToken LeverageToken to rebalance
    /// @param collToAdd Amount of collateral to add
    /// @param collToTake Amount of collateral to remove
    /// @param debtToBorrow Amount of debt to borrow
    /// @param debtToRepay Amount of debt to repay
    /// @return actions Actions to execute
    /// @return tokenIn Token to transfer in
    /// @return tokenOut Token to transfer out
    /// @return amountIn Amount of tokenIn to transfer in
    /// @return amountOut Amount of tokenOut to transfer out
    function _prepareForRebalance(
        ILeverageToken leverageToken,
        RebalanceType rebalanceType,
        uint256 collToAdd,
        uint256 collToTake,
        uint256 debtToBorrow,
        uint256 debtToRepay
    )
        internal
        returns (RebalanceAction[] memory actions, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOut)
    {
        address rebalancer = address(rebalanceAdapter);

        address collateralToken = address(leverageManager.getLeverageTokenCollateralAsset(leverageToken));
        address debtToken = address(leverageManager.getLeverageTokenDebtAsset(leverageToken));

        actions = new RebalanceAction[](4);
        actions[0] = RebalanceAction({actionType: ActionType.AddCollateral, amount: collToAdd});
        actions[1] = RebalanceAction({actionType: ActionType.Repay, amount: debtToRepay});
        actions[2] = RebalanceAction({actionType: ActionType.RemoveCollateral, amount: collToTake});
        actions[3] = RebalanceAction({actionType: ActionType.Borrow, amount: debtToBorrow});

        if (rebalanceType == RebalanceType.UP) {
            tokenIn = IERC20(collateralToken);
            tokenOut = IERC20(debtToken);
            amountIn = collToAdd;
            amountOut = debtToBorrow;
        } else {
            tokenIn = IERC20(debtToken);
            tokenOut = IERC20(collateralToken);
            amountIn = debtToRepay;
            amountOut = collToTake;
        }

        // Mint collateral token to add collateral and debt token to repay debt
        deal(address(collateralToken), rebalancer, collToAdd);
        deal(address(debtToken), rebalancer, debtToRepay);

        vm.startPrank(rebalancer);

        // Approve collateral token to add collateral and debt token to repay debt
        IERC20(collateralToken).approve(address(leverageManager), collToAdd);
        IERC20(debtToken).approve(address(leverageManager), debtToRepay);

        vm.stopPrank();

        return (actions, tokenIn, tokenOut, amountIn, amountOut);
    }

    function _supplyCBBTCForLeverageToken() internal {
        deal(address(CBBTC), address(this), 1000 * 1e18);
        IMorpho morpho = IMorpho(morphoLendingAdapter.morpho());

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            morphoLendingAdapter.marketParams();
        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        CBBTC.approve(address(morpho), 1000 * 1e18);
        morpho.supply(marketParams, 1000 * 1e18, 0, address(this), new bytes(0));
    }

    function _giftUSDCToLeverageToken() internal {
        deal(address(USDC), address(this), 150_000 * 1e6);
        IMorpho morpho = IMorpho(morphoLendingAdapter.morpho());

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            morphoLendingAdapter.marketParams();
        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        USDC.approve(address(morpho), 150_000 * 1e6);
        morpho.supplyCollateral(marketParams, 150_000 * 1e6, address(morphoLendingAdapter), new bytes(0));
    }

    function _mint() internal {
        uint256 sharesToMint = 0.5 ether;
        uint256 collateralToAdd = leverageManager.previewMint(leverageToken, sharesToMint).collateral;
        _mint(leverageToken, user, sharesToMint, collateralToAdd);
    }

    function _mint(ILeverageToken _leverageToken, address _caller, uint256 _sharesToMint, uint256 _collateralToAdd)
        internal
    {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(_leverageToken);
        deal(address(collateralAsset), _caller, _collateralToAdd);

        vm.startPrank(_caller);
        collateralAsset.approve(address(leverageManager), _collateralToAdd);
        leverageManager.mint(_leverageToken, _sharesToMint, _collateralToAdd);
        vm.stopPrank();
    }

    /// @dev Moves price of ETH for given percentage, if percentage is negative it moves price of ETH down
    function _moveBTCPrice(int256 percentage) internal {
        // Move price on ETH long
        (,, address btcOracle,,) = morphoLendingAdapter.marketParams();
        uint256 currentPrice = IOracle(btcOracle).price();
        int256 priceChange = int256(currentPrice) * percentage / MAX_PERCENTAGE;
        uint256 newPrice = uint256(int256(currentPrice) + priceChange);
        vm.mockCall(address(btcOracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(newPrice));
    }

    function getLeverageTokenState(ILeverageToken leverageToken) internal view returns (LeverageTokenState memory) {
        return LeverageManagerHarness(address(leverageManager)).getLeverageTokenState(leverageToken);
    }
}
