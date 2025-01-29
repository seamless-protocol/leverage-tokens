// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Id, MarketParams, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageRouter} from "src/interfaces/ILeverageRouter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockLendingAdapter} from "../mock/MockLendingAdapter.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
import {MockMorpho} from "../mock/MockMorpho.sol";
import {MockSwapper} from "../mock/MockSwapper.sol";
import {LeverageManagerBaseTest} from "../LeverageManager/LeverageManagerBase.t.sol";

contract LendingRouterBaseTest is Test {
    MockERC20 public collateralToken = new MockERC20();
    MockERC20 public debtToken = new MockERC20();
    IStrategy public strategyToken = IStrategy(address(new MockERC20()));

    // Mocked Morpho protocol
    MockMorpho public morpho;

    // Mocked Morpho protocol is setup with a market with id 1 and some default market params
    Id public defaultMarketId;
    MarketParams public defaultMarketParams = MarketParams({
        loanToken: address(debtToken),
        collateralToken: address(collateralToken),
        oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as calls to morpho should be mocked
        irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as calls to morpho should be mocked
        lltv: 1e18 // 100%, doesn't matter for these tests as calls to morpho should be mocked
    });

    MockSwapper public swapper;

    MockLendingAdapter public lendingAdapter;

    MockLeverageManager public leverageManager;

    ILeverageRouter public leverageRouter;

    function setUp() public virtual {
        // Setup mocked contracts
        defaultMarketId = MarketParamsLib.id(defaultMarketParams);
        morpho = new MockMorpho(defaultMarketId, defaultMarketParams);
        lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));
        leverageManager = new MockLeverageManager();
        leverageManager.setStrategyData(strategyToken, collateralToken, debtToken, strategyToken);
        swapper = new MockSwapper();

        // Setup the leverage router
        leverageRouter = new LeverageRouter(
            ILeverageManager(address(leverageManager)), IMorpho(address(morpho)), ISwapper(address(swapper))
        );

        // Setup the tokens
        collateralToken.mockSetDecimals(18);
        debtToken.mockSetDecimals(6);
    }
}
