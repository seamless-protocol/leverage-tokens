// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Id, MarketParams, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageRouterBaseHarness} from "../harness/LeverageRouterBaseHarness.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockLendingAdapter} from "../mock/MockLendingAdapter.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
import {MockMorpho} from "../mock/MockMorpho.sol";

contract LeverageRouterBaseTest is Test {
    MockERC20 public collateralToken = new MockERC20();
    MockERC20 public debtToken = new MockERC20();
    ILeverageToken public leverageToken = ILeverageToken(address(new MockERC20()));

    MockMorpho public morpho;

    // Mocked Morpho protocol is setup with a market with some default market params
    Id public defaultMarketId;
    MarketParams public defaultMarketParams = MarketParams({
        loanToken: address(debtToken),
        collateralToken: address(collateralToken),
        oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as calls to morpho should be mocked
        irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as calls to morpho should be mocked
        lltv: 1e18 // 100%, doesn't matter for these tests as calls to morpho should be mocked
    });

    MockLendingAdapter public lendingAdapter;

    MockLeverageManager public leverageManager;

    LeverageRouterBaseHarness public leverageRouterBase;

    function setUp() public virtual {
        // Setup mocked contracts
        defaultMarketId = MarketParamsLib.id(defaultMarketParams);
        morpho = new MockMorpho(defaultMarketId, defaultMarketParams);
        lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken), address(this));
        leverageManager = new MockLeverageManager();
        leverageManager.setLeverageTokenData(
            leverageToken,
            MockLeverageManager.LeverageTokenData({
                leverageToken: leverageToken,
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                collateralAsset: collateralToken,
                debtAsset: debtToken
            })
        );

        leverageRouterBase =
            new LeverageRouterBaseHarness(ILeverageManager(address(leverageManager)), IMorpho(address(morpho)));
    }

    function test_setUp() public view {
        assertEq(address(leverageRouterBase.leverageManager()), address(leverageManager));
        assertEq(address(leverageRouterBase.morpho()), address(morpho));
    }

    function test_receive() public {
        // Send some ether to the leverage router base
        deal(address(this), 1 ether);

        // Try to send ETH to the contract
        (bool success,) = address(leverageRouterBase).call{value: 1 ether}("");

        // Assert that the transfer was successful
        assertTrue(success);

        // Assert that the contract balance increased
        assertEq(address(leverageRouterBase).balance, 1 ether);
    }
}
