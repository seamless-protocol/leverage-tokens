// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console2} from "forge-std/Test.sol";

// Dependency imports
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {Id, MarketParams, IMorpho, IMorphoBase} from "src/interfaces/IMorpho.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {MockMorpho} from "../../mock/MockMorpho.sol";

contract MorphoLendingAdapterBaseTest is Test {
    MockMorpho public morpho;
    IMorphoLendingAdapter public lendingAdapter;

    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    // Mocked ILeverageManager contract
    ILeverageManager public leverageManager = ILeverageManager(makeAddr("leverageManager"));

    // Mocked Morpho protocol is setup with a market with id 1 and some default market params
    Id public defaultMarketId = Id.wrap(bytes32("1"));
    MarketParams public defaultMarketParams = MarketParams({
        loanToken: address(debtToken),
        collateralToken: address(collateralToken),
        oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as calls to morpho should be mocked
        irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as calls to morpho should be mocked
        lltv: 1e18 // 100%, doesn't matter for these tests as calls to morpho should be mocked
    });

    function setUp() public {
        morpho = new MockMorpho(defaultMarketId, defaultMarketParams);
        lendingAdapter = new MorphoLendingAdapter(leverageManager, IMorpho(address(morpho)));
        MorphoLendingAdapter(address(lendingAdapter)).initialize(defaultMarketId);
    }
}
