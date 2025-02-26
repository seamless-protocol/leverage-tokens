// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {IMorpho, Position, Market} from "@morpho-blue/interfaces/IMorpho.sol";
import {Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract MorphoLendingAdapterTest is Test {
    IERC20 public WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 public USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IMorpho public MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    Id public WETH_USDC_MARKET_ID = Id.wrap(0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda);

    address public leverageManager = makeAddr("LeverageManager");
    MorphoLendingAdapter morphoLendingAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_RPC_URL"), 26901252);

        MorphoLendingAdapter morphoLendingAdapterImplementation =
            new MorphoLendingAdapter(ILeverageManager(leverageManager), MORPHO);

        BeaconProxyFactory morphoLendingAdapterFactory =
            new BeaconProxyFactory(address(morphoLendingAdapterImplementation), address(this));

        morphoLendingAdapter = MorphoLendingAdapter(
            morphoLendingAdapterFactory.createProxy(
                abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, WETH_USDC_MARKET_ID), bytes32(0)
            )
        );
    }

    function testFork_setUp() public view {
        assertEq(address(morphoLendingAdapter.leverageManager()), leverageManager);
        assertEq(address(morphoLendingAdapter.morpho()), address(MORPHO));
        assertEq(address(morphoLendingAdapter.getCollateralAsset()), address(WETH));
        assertEq(address(morphoLendingAdapter.getDebtAsset()), address(USDC));

        assertEq(morphoLendingAdapter.getCollateral(), 0);
        assertEq(morphoLendingAdapter.getCollateralInDebtAsset(), 0);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), 0);
        assertEq(morphoLendingAdapter.getEquityInDebtAsset(), 0);
    }

    /// @dev In this block price on oracle 2376.236961937716262975778546
    function testFork_convertCollateralToDebtAsset() public {
        uint256 result = morphoLendingAdapter.convertCollateralToDebtAsset(1 ether);
        assertEq(result, 2376236961); // 2376.236961

        result = morphoLendingAdapter.convertCollateralToDebtAsset(5 ether);
        assertEq(result, 11881184809); // 11881.1848097

        result = morphoLendingAdapter.convertCollateralToDebtAsset(10 ether);
        assertEq(result, 23762369619); // 23762.369619

        result = morphoLendingAdapter.convertCollateralToDebtAsset(0.5 ether);
        assertEq(result, 1188118480); // 1188.11848097
    }

    /// @dev In this block price on oracle 2376.236961937716262975778546
    function testFork_convertDebtToCollateralAsset() public {
        uint256 result = morphoLendingAdapter.convertDebtToCollateralAsset(1000_000000);
        assertEq(result, 0.420833450542972861 * 1 ether); // 0.420833450542972861

        result = morphoLendingAdapter.convertDebtToCollateralAsset(80_000_000000);
        assertEq(result, 33.666676043437828823 * 1 ether); // 33.666676043437828823
    }

    /// @dev In this block price on oracle 2376.236961937716262975778546
    function testFork_getEquityInDebtAsset() public {
        uint256 collateral = 1e18;
        uint256 debt = 2000e6;

        _addCollateral(address(this), collateral);
        _borrow(leverageManager, debt);

        assertEq(morphoLendingAdapter.getEquityInDebtAsset(), 376236960); // 376.236961 but rounded down to 376.236960
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_addCollateral(address sender, uint128 amount) public {
        amount = uint128(bound(amount, 1, type(uint128).max));

        Market memory marketBefore = MORPHO.market(WETH_USDC_MARKET_ID);
        _addCollateral(sender, amount);
        Market memory marketAfter = MORPHO.market(WETH_USDC_MARKET_ID);

        assertEq(marketAfter.totalBorrowAssets, marketBefore.totalBorrowAssets);

        Position memory position = MORPHO.position(WETH_USDC_MARKET_ID, address(morphoLendingAdapter));
        assertEq(position.collateral, amount);

        assertEq(morphoLendingAdapter.getCollateral(), amount);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), amount);

        assertEq(WETH.balanceOf(sender), 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_removeCollateral(uint128 collateralBefore, uint128 collateralToRemove) public {
        // Bound collateralToRemove to be less than or equal to collateralBefore
        collateralBefore = uint128(bound(collateralBefore, 1, type(uint128).max));
        collateralToRemove = uint128(bound(collateralToRemove, 1, collateralBefore));

        _addCollateral(address(this), collateralBefore);
        _removeCollateral(leverageManager, collateralToRemove);

        Position memory position = MORPHO.position(WETH_USDC_MARKET_ID, address(morphoLendingAdapter));
        assertEq(position.collateral, collateralBefore - collateralToRemove);

        assertEq(morphoLendingAdapter.getCollateral(), collateralBefore - collateralToRemove);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), collateralBefore - collateralToRemove);

        assertEq(WETH.balanceOf(leverageManager), collateralToRemove);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_removeCollateral_RevertIf_CallerIsNotLeverageManager(address caller, uint256 amount) public {
        vm.assume(caller != leverageManager);
        vm.expectRevert(ILendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        morphoLendingAdapter.removeCollateral(amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_borrow(uint32 amount) public {
        uint256 totalSupplyAssetsBefore =
            MorphoBalancesLib.expectedTotalSupplyAssets(MORPHO, MORPHO.idToMarketParams(WETH_USDC_MARKET_ID));
        uint256 totalBorrowAssetsBefore =
            MorphoBalancesLib.expectedTotalBorrowAssets(MORPHO, MORPHO.idToMarketParams(WETH_USDC_MARKET_ID));

        uint256 maxBorrow = totalSupplyAssetsBefore - totalBorrowAssetsBefore;

        // Bound amount to max borrow available in the morpho market
        amount = uint32(bound(amount, 0, maxBorrow));

        // Put max collateral so borrow tx does not revert due to insufficient collateral
        _addCollateral(address(this), type(uint128).max);

        _borrow(leverageManager, amount);

        // Check if borrow actually increased total borrow assets
        // Total borrow assets can be even bigger because of accrue interest call in Morpho during borrow function call
        Market memory marketAfter = MORPHO.market(WETH_USDC_MARKET_ID);
        assertEq(marketAfter.totalBorrowAssets, totalBorrowAssetsBefore + amount);

        // Validate that borrow assets are correctly calculated
        // Allow for 1 wei difference in favour of Morpho due to rounding on their end
        uint256 expectedBorrowAssets = MorphoBalancesLib.expectedBorrowAssets(
            MORPHO, MORPHO.idToMarketParams(WETH_USDC_MARKET_ID), address(morphoLendingAdapter)
        );
        assertGe(expectedBorrowAssets, amount);
        assertLe(expectedBorrowAssets, amount + 1);

        assertEq(morphoLendingAdapter.getCollateral(), type(uint128).max);
        assertEq(morphoLendingAdapter.getDebt(), expectedBorrowAssets);

        // Validate that debt is correctly transferred to leverage manager
        assertEq(USDC.balanceOf(address(leverageManager)), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_borrow_RevertIf_CallerIsNotLeverageManager(address caller, uint256 amount) public {
        vm.assume(caller != leverageManager);
        vm.expectRevert(ILendingAdapter.Unauthorized.selector);
        vm.prank(caller);
        morphoLendingAdapter.borrow(amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_repay(address caller, uint128 debtBefore, uint128 debtToRepay) public {
        uint256 totalSupplyAssetsBefore =
            MorphoBalancesLib.expectedTotalSupplyAssets(MORPHO, MORPHO.idToMarketParams(WETH_USDC_MARKET_ID));
        uint256 totalBorrowAssetsBefore =
            MorphoBalancesLib.expectedTotalBorrowAssets(MORPHO, MORPHO.idToMarketParams(WETH_USDC_MARKET_ID));

        uint256 maxBorrow = totalSupplyAssetsBefore - totalBorrowAssetsBefore;

        // Bound amount to max borrow available in the morpho market
        debtBefore = uint32(bound(debtBefore, 1, maxBorrow));
        debtToRepay = uint32(bound(debtToRepay, 1, debtBefore));

        _addCollateral(caller, type(uint128).max);
        _borrow(leverageManager, debtBefore);
        _repay(caller, debtToRepay);

        Market memory marketAfter = MORPHO.market(WETH_USDC_MARKET_ID);
        assertEq(marketAfter.totalBorrowAssets, totalBorrowAssetsBefore + debtBefore - debtToRepay);

        // Validate that borrow assets are correctly calculated
        // Allow for 1 wei difference in favour of Morpho due to rounding on their end
        uint256 expectedBorrowAssets = MorphoBalancesLib.expectedBorrowAssets(
            MORPHO, MORPHO.idToMarketParams(WETH_USDC_MARKET_ID), address(morphoLendingAdapter)
        );
        assertGe(expectedBorrowAssets, debtBefore - debtToRepay);
        assertLe(expectedBorrowAssets, debtBefore - debtToRepay + 1);

        assertEq(morphoLendingAdapter.getCollateral(), type(uint128).max);
        assertEq(morphoLendingAdapter.getDebt(), expectedBorrowAssets);

        assertEq(USDC.balanceOf(caller), 0);
    }

    function _addCollateral(address caller, uint256 amount) internal {
        deal(address(WETH), caller, amount);

        vm.startPrank(caller);
        WETH.approve(address(morphoLendingAdapter), amount);
        morphoLendingAdapter.addCollateral(amount);
        vm.stopPrank();
    }

    function _removeCollateral(address caller, uint256 amount) internal {
        vm.prank(caller);
        morphoLendingAdapter.removeCollateral(amount);
    }

    function _borrow(address caller, uint256 amount) internal {
        vm.prank(caller);
        morphoLendingAdapter.borrow(amount);
    }

    function _repay(address caller, uint256 amount) internal {
        deal(address(USDC), caller, amount);

        vm.startPrank(caller);
        USDC.approve(address(morphoLendingAdapter), amount);
        morphoLendingAdapter.repay(amount);
        vm.stopPrank();
    }
}
