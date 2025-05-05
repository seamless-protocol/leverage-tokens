// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MarketParams, Id, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {ExternalAction, LeverageTokenConfig} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {AdaptiveCurveIrm} from "test/invariant/morpho/AdaptiveCurveIrm.sol";
import {MORPHO_BYTECODE} from "test/invariant/morpho/Morpho.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockMorphoOracle} from "test/unit/mock/MockMorphoOracle.sol";

abstract contract InvariantTestBase is Test {
    struct MorphoInitMarketParams {
        address collateralAsset;
        address debtAsset;
        uint256 initOraclePrice;
        uint256 lltv;
        uint256 initMarketSupply;
        uint256 initMarketCollateral;
        uint256 initMarketDebt;
    }

    uint256 public BASE_RATIO;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");
    address public feeManagerRole = makeAddr("feeManagerRole");
    address public treasury = makeAddr("treasury");
    IMorpho public morpho;
    address public irm;

    LeverageManagerHarness public leverageManager;
    LeverageManagerHandler public leverageManagerHandler;

    RebalanceAdapter public rebalanceAdapterImplementation;

    function setUp() public {
        address leverageTokenImplementation = address(new LeverageToken());

        BeaconProxyFactory leverageTokenFactory = new BeaconProxyFactory(leverageTokenImplementation, address(this));
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            leverageManagerImplementation,
            abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin, address(leverageTokenFactory))
        );
        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        rebalanceAdapterImplementation = new RebalanceAdapter();

        vm.startPrank(defaultAdmin);
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), feeManagerRole);
        vm.stopPrank();

        vm.prank(feeManagerRole);
        leverageManager.setTreasury(treasury);

        BASE_RATIO = leverageManager.BASE_RATIO();

        // Deploy Morpho
        morpho = _deployMorpho();
        irm = _deployAdaptiveCurveIrm();

        _initLeverageManagerHandler(leverageManager);

        targetContract(address(leverageManagerHandler));
        targetSelector(FuzzSelector({addr: address(leverageManagerHandler), selectors: _fuzzedSelectors()}));
    }

    function test_invariantSetup_Morpho() public view {
        assertEq(morpho.owner(), defaultAdmin);
        assertTrue(morpho.isIrmEnabled(irm));
    }

    function _deployRebalanceAdapter(RebalanceAdapter.RebalanceAdapterInitParams memory initParams)
        internal
        returns (RebalanceAdapter)
    {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(rebalanceAdapterImplementation),
            abi.encodeWithSelector(RebalanceAdapter.initialize.selector, initParams)
        );

        return RebalanceAdapter(address(proxy));
    }

    function _createActors(uint256 numActors) internal returns (address[] memory) {
        address[] memory actors = new address[](numActors);
        for (uint256 i = 0; i < numActors; i++) {
            actors[i] = makeAddr(string.concat("actor-", Strings.toString(i)));
        }
        return actors;
    }

    function _fuzzedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = LeverageManagerHandler.mint.selector;
        selectors[1] = LeverageManagerHandler.redeem.selector;
        selectors[2] = LeverageManagerHandler.addCollateral.selector;
        selectors[3] = LeverageManagerHandler.repayDebt.selector;
        selectors[4] = LeverageManagerHandler.updateOraclePrice.selector;
        return selectors;
    }

    function _initLeverageManagerHandler(LeverageManagerHarness _leverageManager) internal {
        ILeverageToken[] memory leverageTokens = new ILeverageToken[](1);

        MockERC20 collateralAsset = new MockERC20();
        MockERC20 debtAsset = new MockERC20();
        debtAsset.mockSetDecimals(6);

        leverageTokens[0] = _initLeverageToken(
            "Strategy A",
            "STRAT-A",
            MorphoInitMarketParams({
                collateralAsset: address(collateralAsset),
                debtAsset: address(debtAsset),
                initOraclePrice: 1e27, // 1 ETH = 1000 USDC
                lltv: 0.86e18, // 86% LLTV
                // Half of the maximum amount allowed by Morpho (uint128.max). 1e6 for the virtual offset they use.
                initMarketSupply: type(uint128).max / 1e6 / 2,
                initMarketCollateral: 20000e18, // 20000 ETH initial collateral (== 20m USDC)
                initMarketDebt: 10000000e6 // 10m USDC initial debt
            }),
            100, // 1% mint token fee
            100, // 1% redeem token fee
            RebalanceAdapter.RebalanceAdapterInitParams({
                owner: address(this),
                authorizedCreator: address(this),
                leverageManager: leverageManager,
                minCollateralRatio: 1 * BASE_RATIO,
                targetCollateralRatio: 2 * BASE_RATIO,
                maxCollateralRatio: 3 * BASE_RATIO,
                auctionDuration: 10 minutes,
                initialPriceMultiplier: 1.05e18, // 105%
                minPriceMultiplier: 0.9e18, // 90%
                preLiquidationCollateralRatioThreshold: 102e18, // 102%
                rebalanceReward: 5_00 // 5%
            })
        );

        // TODO: Add minimum fees leverage token config (e.g. 0.01% fee, 1 wei).
        // If issues arise, then we may need to ensure fee is set to at least 10 wei.

        address[] memory actors = _createActors(10);

        leverageManagerHandler = new LeverageManagerHandler(_leverageManager, leverageTokens, actors);

        vm.label(address(leverageManagerHandler), "leverageManagerHandler");
    }

    function _initLeverageToken(
        string memory name,
        string memory symbol,
        MorphoInitMarketParams memory marketParams,
        uint256 mintTokenFee,
        uint256 redeemTokenFee,
        RebalanceAdapter.RebalanceAdapterInitParams memory initParams
    ) internal returns (ILeverageToken leverageToken) {
        Id morphoMarketId = _initMorphoMarket(marketParams);

        ILendingAdapter lendingAdapter = new MorphoLendingAdapter(leverageManager, morpho);
        MorphoLendingAdapter(address(lendingAdapter)).initialize(morphoMarketId, address(this));

        IRebalanceAdapterBase rebalanceAdapter = _deployRebalanceAdapter(initParams);

        vm.mockCall(
            address(rebalanceAdapter),
            abi.encodeWithSelector(IRebalanceAdapterBase.postLeverageTokenCreation.selector),
            abi.encode()
        );

        LeverageTokenConfig memory config = LeverageTokenConfig({
            lendingAdapter: lendingAdapter,
            rebalanceAdapter: rebalanceAdapter,
            mintTokenFee: mintTokenFee,
            redeemTokenFee: redeemTokenFee
        });

        return leverageManager.createNewLeverageToken(config, name, symbol);
    }

    function _initMorphoMarket(MorphoInitMarketParams memory marketInitParams) internal returns (Id) {
        vm.prank(defaultAdmin);
        morpho.enableLltv(marketInitParams.lltv);

        MockMorphoOracle oracle = new MockMorphoOracle(marketInitParams.initOraclePrice);

        MarketParams memory marketParams = MarketParams({
            loanToken: marketInitParams.debtAsset,
            collateralToken: marketInitParams.collateralAsset,
            oracle: address(oracle),
            irm: irm,
            lltv: marketInitParams.lltv
        });

        // Note: This will revert if a market has already been created with the same params.
        morpho.createMarket(marketParams);

        // Add supply to the market.
        deal(address(marketInitParams.debtAsset), address(this), marketInitParams.initMarketSupply);
        IERC20(marketInitParams.debtAsset).approve(address(morpho), marketInitParams.initMarketSupply);
        morpho.supply(marketParams, marketInitParams.initMarketSupply, 0, address(this), bytes(""));

        // Add collateral to the market.
        deal(address(marketInitParams.collateralAsset), address(this), marketInitParams.initMarketCollateral);
        IERC20(marketInitParams.collateralAsset).approve(address(morpho), marketInitParams.initMarketCollateral);
        morpho.supplyCollateral(marketParams, marketInitParams.initMarketCollateral, address(this), bytes(""));

        // Add debt to the market.
        deal(address(marketInitParams.debtAsset), address(this), marketInitParams.initMarketDebt);
        IERC20(marketInitParams.debtAsset).approve(address(morpho), marketInitParams.initMarketDebt);
        morpho.borrow(marketParams, marketInitParams.initMarketDebt, 0, address(this), address(this));

        return MarketParamsLib.id(marketParams);
    }

    function _setTreasuryActionFee(ExternalAction action, uint128 newTreasuryFee) internal {
        vm.prank(feeManagerRole);
        leverageManager.setTreasuryActionFee(action, newTreasuryFee);
    }

    function _setManagementFee(uint128 newManagementFee) internal {
        vm.prank(feeManagerRole);
        leverageManager.setManagementFee(newManagementFee);
    }

    function _deployAdaptiveCurveIrm() internal returns (address) {
        address _irm = address(new AdaptiveCurveIrm(address(morpho)));

        vm.prank(defaultAdmin);
        morpho.enableIrm(_irm);

        return _irm;
    }

    function _deployMorpho() internal returns (IMorpho) {
        IMorpho _morpho = IMorpho(makeAddr("morpho"));

        // Code obtained using `cast code` from the Morpho deployment on Base.
        vm.etch(address(_morpho), MORPHO_BYTECODE);

        vm.prank(address(0));
        _morpho.setOwner(defaultAdmin);

        return _morpho;
    }
}
