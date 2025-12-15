// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {IMorpho, Position, Market} from "@morpho-blue/interfaces/IMorpho.sol";
import {Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

// Internal imports
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {IntegrationTestBase} from "./IntegrationTestBase.t.sol";
import {LeverageTokenConfig} from "src/types/DataTypes.sol";
import {MorphoLendingAdapterTestUtils} from "../MorphoLendingAdapterTestUtils.t.sol";

contract MorphoLendingAdapterTest is IntegrationTestBase, MorphoLendingAdapterTestUtils {
    Id public constant MARKET_ID = CBBTC_USDC_MARKET_ID;
    IERC20 public constant COLLATERAL_ASSET = CBBTC;
    IERC20 public constant DEBT_ASSET = USDC;

    function testFork_getLiquidationPenalty() public {
        IMorphoLendingAdapter lendingAdapter =
            morphoLendingAdapterFactory.deployAdapter(MARKET_ID, address(this), bytes32(uint256(1)));

        assertEq(lendingAdapter.getLiquidationPenalty(), 0.043841336116910229e18);
    }

    function testFork_createNewLeverageToken_RevertIf_LendingAdapterIsAlreadyInUse() public {
        vm.expectRevert(abi.encodeWithSelector(IMorphoLendingAdapter.LendingAdapterAlreadyInUse.selector));
        leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: morphoLendingAdapter,
                rebalanceAdapter: IRebalanceAdapterBase(address(0)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            "LT Name",
            "LT"
        );
    }

    function testFork_convertCollateralToDebtAsset() public view {
        uint256 result = morphoLendingAdapter.convertCollateralToDebtAsset(1e8);
        assertEq(result, 109472.330695e6);

        result = morphoLendingAdapter.convertCollateralToDebtAsset(5e8);
        assertEq(result, 547361.653475e6);

        result = morphoLendingAdapter.convertCollateralToDebtAsset(10e8);
        assertEq(result, 1094723.30695e6);

        result = morphoLendingAdapter.convertCollateralToDebtAsset(0.5e8);
        assertEq(result, 54736.165347e6);
    }

    function testFork_convertDebtToCollateralAsset() public view {
        uint256 result = morphoLendingAdapter.convertDebtToCollateralAsset(1000e6);
        assertEq(result, 0.00913473e8);

        result = morphoLendingAdapter.convertDebtToCollateralAsset(109472.330695e6);
        assertEq(result, 1e8);
    }

    function testFork_getEquityInDebtAsset() public {
        uint256 collateral = 1e8;
        uint256 debt = 90000e6;

        _addCollateral(address(this), collateral);
        _borrow(address(leverageManager), debt);

        assertEq(morphoLendingAdapter.getEquityInDebtAsset(), 19472.330694e6);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_addCollateral(uint128 amount) public {
        address sender = makeAddr("sender");
        amount = uint128(bound(amount, 1, type(uint128).max));

        Market memory marketBefore = MORPHO.market(MARKET_ID);
        _addCollateral(sender, amount);
        Market memory marketAfter = MORPHO.market(MARKET_ID);

        assertEq(marketAfter.totalBorrowAssets, marketBefore.totalBorrowAssets);

        Position memory position = MORPHO.position(MARKET_ID, address(morphoLendingAdapter));
        assertEq(position.collateral, amount);

        assertEq(morphoLendingAdapter.getCollateral(), amount);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), amount);

        assertEq(COLLATERAL_ASSET.balanceOf(sender), 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_removeCollateral(uint128 collateralBefore, uint128 collateralToRemove) public {
        // Bound collateralToRemove to be less than or equal to collateralBefore
        collateralBefore = uint128(bound(collateralBefore, 1, type(uint128).max));
        collateralToRemove = uint128(bound(collateralToRemove, 1, collateralBefore));

        _addCollateral(address(this), collateralBefore);
        _removeCollateral(address(leverageManager), collateralToRemove);

        Position memory position = MORPHO.position(MARKET_ID, address(morphoLendingAdapter));
        assertEq(position.collateral, collateralBefore - collateralToRemove);

        assertEq(morphoLendingAdapter.getCollateral(), collateralBefore - collateralToRemove);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), collateralBefore - collateralToRemove);

        assertEq(COLLATERAL_ASSET.balanceOf(address(leverageManager)), collateralToRemove);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_removeCollateral_RevertIf_CallerIsNotLeverageManager(address caller, uint256 amount) public {
        vm.assume(caller != address(leverageManager));
        vm.expectRevert(ILendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        morphoLendingAdapter.removeCollateral(amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_borrow(uint32 amount) public {
        uint256 totalSupplyAssetsBefore =
            MorphoBalancesLib.expectedTotalSupplyAssets(MORPHO, MORPHO.idToMarketParams(MARKET_ID));
        uint256 totalBorrowAssetsBefore =
            MorphoBalancesLib.expectedTotalBorrowAssets(MORPHO, MORPHO.idToMarketParams(MARKET_ID));

        uint256 maxBorrow = totalSupplyAssetsBefore - totalBorrowAssetsBefore;
        assertEq(maxBorrow, 36961106.867558e6);

        // Bound amount to max borrow available in the morpho market
        amount = uint32(bound(amount, 1, maxBorrow));

        // Add collateral so borrow tx does not revert due to insufficient collateral
        uint256 collateral = 500e8;
        _addCollateral(address(this), collateral);

        _borrow(address(leverageManager), amount);

        // Check if borrow actually increased total borrow assets
        // Total borrow assets can be even bigger because of accrue interest call in Morpho during borrow function call
        Market memory marketAfter = MORPHO.market(MARKET_ID);
        assertEq(marketAfter.totalBorrowAssets, totalBorrowAssetsBefore + amount);

        // Validate that borrow assets are correctly calculated
        // Allow for 1 wei difference in favour of Morpho due to rounding on their end
        uint256 expectedBorrowAssets = MorphoBalancesLib.expectedBorrowAssets(
            MORPHO, MORPHO.idToMarketParams(MARKET_ID), address(morphoLendingAdapter)
        );
        assertGe(expectedBorrowAssets, amount);
        assertLe(expectedBorrowAssets, uint256(amount) + 1);

        assertEq(morphoLendingAdapter.getCollateral(), collateral);
        assertEq(morphoLendingAdapter.getDebt(), expectedBorrowAssets);

        // Validate that debt is correctly transferred to leverage manager
        assertEq(DEBT_ASSET.balanceOf(address(leverageManager)), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_borrow_RevertIf_CallerIsNotLeverageManager(address caller, uint256 amount) public {
        vm.assume(caller != address(leverageManager));
        vm.expectRevert(ILendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        morphoLendingAdapter.borrow(amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_repay(uint128 debtBefore, uint128 debtToRepay) public {
        address caller = makeAddr("caller");

        uint256 totalSupplyAssetsBefore =
            MorphoBalancesLib.expectedTotalSupplyAssets(MORPHO, MORPHO.idToMarketParams(MARKET_ID));
        uint256 totalBorrowAssetsBefore =
            MorphoBalancesLib.expectedTotalBorrowAssets(MORPHO, MORPHO.idToMarketParams(MARKET_ID));

        uint256 maxBorrow = totalSupplyAssetsBefore - totalBorrowAssetsBefore;
        assertEq(maxBorrow, 36961106.867558e6);

        // Bound amount to max borrow available in the morpho market
        debtBefore = uint32(bound(debtBefore, 1, maxBorrow));
        debtToRepay = uint32(bound(debtToRepay, 1, debtBefore));

        uint256 collateral = 500e8;
        _addCollateral(caller, collateral);
        _borrow(address(leverageManager), debtBefore);
        _repay(caller, debtToRepay);

        Market memory marketAfter = MORPHO.market(MARKET_ID);
        assertEq(marketAfter.totalBorrowAssets, totalBorrowAssetsBefore + debtBefore - debtToRepay);

        // Validate that borrow assets are correctly calculated
        // Allow for 1 wei difference in favour of Morpho due to rounding on their end
        uint256 expectedBorrowAssets = MorphoBalancesLib.expectedBorrowAssets(
            MORPHO, MORPHO.idToMarketParams(MARKET_ID), address(morphoLendingAdapter)
        );
        assertGe(expectedBorrowAssets, debtBefore - debtToRepay);
        assertLe(expectedBorrowAssets, debtBefore - debtToRepay + 1);

        assertEq(morphoLendingAdapter.getCollateral(), collateral);
        assertEq(morphoLendingAdapter.getDebt(), expectedBorrowAssets);

        assertEq(DEBT_ASSET.balanceOf(caller), 0);
    }

    function _addCollateral(address caller, uint256 amount) internal {
        _addCollateral(morphoLendingAdapter, COLLATERAL_ASSET, caller, amount);
    }

    function _removeCollateral(address caller, uint256 amount) internal {
        _removeCollateral(morphoLendingAdapter, caller, amount);
    }

    function _borrow(address caller, uint256 amount) internal {
        _borrow(morphoLendingAdapter, caller, amount);
    }

    function _repay(address caller, uint256 amount) internal {
        _repay(morphoLendingAdapter, DEBT_ASSET, caller, amount);
    }
}
