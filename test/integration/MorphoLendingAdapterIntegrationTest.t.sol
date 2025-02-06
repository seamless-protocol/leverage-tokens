// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Id, MarketParams, Position} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {IntegrationBase} from "./IntegrationBase.t.sol";

import {console2} from "forge-std/console2.sol";

contract MorphoLendingAdapterIntegrationTest is IntegrationBase {
    Id public WETH_USDC_MARKET_ID;

    // The total borrow assets available in the WETH_USDC market is 3356056554827 USDC at the forked block
    uint256 public constant WETH_USDC_MARKET_TOTAL_BORROW_ASSETS_AVAILABLE = 3_356_056_554_827;

    IMorphoLendingAdapter public lendingAdapterWethUsdc;

    MarketParams public lendingAdapterWethUsdcMarketParams;
    IERC20 public weth;
    IERC20 public usdc;

    function setUp() public override {
        super.setUp();

        WETH_USDC_MARKET_ID = Id.wrap(0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda);

        lendingAdapterWethUsdc = IMorphoLendingAdapter(
            morphoLendingAdapterFactory.createProxy(
                abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, WETH_USDC_MARKET_ID), bytes32(0)
            )
        );

        lendingAdapterWethUsdcMarketParams = MORPHO.idToMarketParams(WETH_USDC_MARKET_ID);
        weth = IERC20(lendingAdapterWethUsdcMarketParams.collateralToken);
        usdc = IERC20(lendingAdapterWethUsdcMarketParams.loanToken);

        vm.label(address(lendingAdapterWethUsdc), "lendingAdapterWethUsdc");
    }

    function _addCollateral(uint256 amount) internal {
        deal(address(weth), address(this), amount);
        weth.approve(address(lendingAdapterWethUsdc), amount);
        lendingAdapterWethUsdc.addCollateral(amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_DeployMorphoLendingAdapterFromFactory(bytes32 salt) public {
        address expectedLendingAdapterAddress = morphoLendingAdapterFactory.computeProxyAddress(
            address(this), abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, WETH_USDC_MARKET_ID), salt
        );
        address lendingAdapter = morphoLendingAdapterFactory.createProxy(
            abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, WETH_USDC_MARKET_ID), salt
        );

        assertEq(
            lendingAdapter,
            expectedLendingAdapterAddress,
            "Expected computed address and deployed address to be the same"
        );

        // Check that saved market params match morpho market params
        MarketParams memory morphoMarketParams = MORPHO.idToMarketParams(WETH_USDC_MARKET_ID);
        (address savedLoanToken, address savedCollateralToken, address savedOracle, address savedIrm, uint256 savedLltv)
        = IMorphoLendingAdapter(address(lendingAdapter)).marketParams();
        assertEq(savedLoanToken, morphoMarketParams.loanToken, "Expected loan token to be the zero address");
        assertEq(
            savedCollateralToken, morphoMarketParams.collateralToken, "Expected collateral token to be the zero address"
        );
        assertEq(savedOracle, morphoMarketParams.oracle, "Expected oracle to be the zero address");
        assertEq(savedIrm, morphoMarketParams.irm, "Expected irm to be the zero address");
        assertEq(savedLltv, morphoMarketParams.lltv, "Expected lltv to be zero");
    }

    /// forge-config: default.fuzz.runs = 1
    function testForkFuzz_DeployMorphoLendingAdapterFromFactory_WithInvalidMarketId(Id invalidMarketId, bytes32 salt)
        public
    {
        // Check that the invalidMarketId is an invalid market. Invalid markets have loanToken and collateralToken set to the zero address.
        // If it is valid, we need to generate a new invalid market ID.
        MarketParams memory invalidMarketParams = MORPHO.idToMarketParams(invalidMarketId);
        do {
            invalidMarketId = Id.wrap(bytes32(uint256(keccak256(abi.encode(invalidMarketId))) + 1));
            invalidMarketParams = MORPHO.idToMarketParams(invalidMarketId);
        } while (invalidMarketParams.loanToken != address(0) || invalidMarketParams.collateralToken != address(0));

        vm.expectRevert(IMorphoLendingAdapter.InvalidMarketId.selector);
        morphoLendingAdapterFactory.createProxy(
            abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, invalidMarketId), salt
        );
    }

    function testFork_convertCollateralToDebtAsset() public view {
        uint256 debt = lendingAdapterWethUsdc.convertCollateralToDebtAsset(1 ether);
        assertEq(
            debt,
            3_392_292_471,
            "Expected 1 ether debt (1 WETH) to be 3392292471 collateral (3392.292471 USDC) at the current block"
        );
    }

    function testFork_convertDebtToCollateralAsset() public view {
        uint256 collateral = lendingAdapterWethUsdc.convertDebtToCollateralAsset(1000e6);
        assertEq(
            collateral,
            0.294785903153823706e18,
            "Expected 1000e6 collateral (1000 USDC) to be 0.294785903153823706e18 debt (~0.2947 WETH) at the current block"
        );
    }

    function testFork_getCollateral_NoCollateralSupplied() public view {
        uint256 collateral = lendingAdapterWethUsdc.getCollateral();
        assertEq(collateral, 0);
    }

    function testFork_getCollateral_CollateralSupplied() public {
        uint256 depositAmount = 1 ether;

        _addCollateral(depositAmount);

        uint256 collateral = lendingAdapterWethUsdc.getCollateral();
        assertEq(collateral, depositAmount);
    }

    function testFork_getDebt_NoDebtBorrowed() public view {
        uint256 debt = lendingAdapterWethUsdc.getDebt();
        assertEq(debt, 0);
    }

    function testFork_getDebt_DebtBorrowed() public {
        uint256 depositAmount = 1 ether;
        uint256 borrowAmount = 1000e6;

        _addCollateral(depositAmount);

        vm.prank(address(leverageManager));
        lendingAdapterWethUsdc.borrow(borrowAmount);

        uint256 debt = lendingAdapterWethUsdc.getDebt();
        // The amount of assets returned by MorphoBalancesLib is calculated by rounding the exchange rate of shares to assets up.
        assertEq(debt, borrowAmount + 1);
    }

    function testFork_getEquityInDebtAsset_NoEquity() public view {
        uint256 equity = lendingAdapterWethUsdc.getEquityInDebtAsset();
        assertEq(equity, 0);
    }

    function testFork_getEquityInDebtAsset_WithEquity() public {
        uint256 depositAmount = 1 ether;
        uint256 borrowAmount = 1000e6;

        _addCollateral(depositAmount);

        vm.prank(address(leverageManager));
        lendingAdapterWethUsdc.borrow(borrowAmount);

        uint256 collateralInDebtAsset = lendingAdapterWethUsdc.getCollateralInDebtAsset();
        uint256 debt = lendingAdapterWethUsdc.getDebt();
        uint256 equity = lendingAdapterWethUsdc.getEquityInDebtAsset();

        assertEq(collateralInDebtAsset, 3392292471);
        // The amount of assets returned by MorphoBalancesLib is calculated by rounding the exchange rate of shares to assets up.
        assertEq(debt, borrowAmount + 1);
        assertEq(equity, collateralInDebtAsset - debt);
    }

    // We use uint120 to avoid overflows, as the maximum amount of collateral and debt in morpho is type(uint128).max
    function testForkFuzz_addCollateral(uint120 depositAmount) public {
        vm.assume(depositAmount > 0);

        _addCollateral(depositAmount);

        uint256 collateral = lendingAdapterWethUsdc.getCollateral();
        assertEq(collateral, depositAmount);
    }

    function testForkFuzz_removeCollateral(uint120 withdrawAmount, uint120 depositAmount) public {
        vm.assume(withdrawAmount > 0);

        depositAmount = uint120(bound(depositAmount, withdrawAmount, type(uint120).max));

        _addCollateral(depositAmount);

        vm.prank(address(leverageManager));
        lendingAdapterWethUsdc.removeCollateral(withdrawAmount);

        uint256 collateral = lendingAdapterWethUsdc.getCollateral();
        assertEq(collateral, depositAmount - withdrawAmount);
        assertEq(weth.balanceOf(address(leverageManager)), withdrawAmount);
    }

    function testFork_borrow() public {
        uint256 borrowAmount = 1e6;

        _addCollateral(1 ether); // Sufficient collateral to borrow 1e6 USDC

        vm.prank(address(leverageManager));
        lendingAdapterWethUsdc.borrow(borrowAmount);

        assertEq(usdc.balanceOf(address(leverageManager)), borrowAmount);
    }

    function testForkFuzz_borrow(uint48 borrowAmount) public {
        borrowAmount = uint48(bound(borrowAmount, 1, WETH_USDC_MARKET_TOTAL_BORROW_ASSETS_AVAILABLE));

        uint256 requiredCollateralInDebtAsset = Math.mulDiv(
            uint256(borrowAmount) + 1, // Add 1 because borrow amount must result in < the market's LLTV
            1e18,
            lendingAdapterWethUsdcMarketParams.lltv,
            Math.Rounding.Ceil // Use Rounding.Up to ensure sufficient collateral
        );
        uint256 requiredCollateral = lendingAdapterWethUsdc.convertDebtToCollateralAsset(requiredCollateralInDebtAsset);

        _addCollateral(requiredCollateral);

        vm.prank(address(leverageManager));
        lendingAdapterWethUsdc.borrow(borrowAmount);

        assertEq(usdc.balanceOf(address(leverageManager)), borrowAmount);
    }

    function testFork_repay() public {
        uint256 borrowAmount = 1e6;

        uint256 collateralAmount = 1 ether; // Sufficient collateral to borrow 1e6 USDC
        _addCollateral(collateralAmount);

        vm.startPrank(address(leverageManager));

        lendingAdapterWethUsdc.borrow(borrowAmount);
        usdc.approve(address(lendingAdapterWethUsdc), borrowAmount);
        lendingAdapterWethUsdc.repay(borrowAmount);

        vm.stopPrank();

        uint256 debt = lendingAdapterWethUsdc.getDebt();
        // getDebt uses MorphoBalancesLib.expectedBorrowAssets which rounds the calculation of borrow shares to assets up
        assertEq(debt, 1);
    }

    function testForkFuzz_repay(uint48 borrowAmount, uint48 repayAmount) public {
        borrowAmount = uint48(bound(borrowAmount, 1, WETH_USDC_MARKET_TOTAL_BORROW_ASSETS_AVAILABLE));
        uint256 requiredCollateralInDebtAsset = Math.mulDiv(
            uint256(borrowAmount) + 1, // Add 1 because borrow amount must result in < the market's LLTV
            1e18,
            lendingAdapterWethUsdcMarketParams.lltv,
            Math.Rounding.Ceil // Use Rounding.Up to ensure sufficient collateral
        );
        uint256 requiredCollateral = lendingAdapterWethUsdc.convertDebtToCollateralAsset(requiredCollateralInDebtAsset);
        repayAmount = uint48(bound(repayAmount, 1, borrowAmount));

        _addCollateral(requiredCollateral);

        vm.startPrank(address(leverageManager));

        lendingAdapterWethUsdc.borrow(borrowAmount);
        usdc.approve(address(lendingAdapterWethUsdc), repayAmount);
        lendingAdapterWethUsdc.repay(repayAmount);

        vm.stopPrank();

        uint256 debt = lendingAdapterWethUsdc.getDebt();
        // getDebt uses MorphoBalancesLib.expectedBorrowAssets which rounds the calculation of borrow shares to assets up
        assertTrue(debt == borrowAmount - repayAmount || debt == borrowAmount - repayAmount + 1);

        assertEq(usdc.balanceOf(address(leverageManager)), borrowAmount - repayAmount);
    }
}
