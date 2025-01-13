// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {Id, MarketParams, IMorpho} from "src/vendor/morpho/IMorpho.sol";
import {MorphoLendingAdapter} from "src/adapters/lending/morpho/MorphoLendingAdapter.sol";
import {MockMorpho} from "../../mock/MockMorpho.sol";

contract MorphoLendingAdapterInitializeTest is Test {
    MorphoLendingAdapter public lendingAdapter;
    MockMorpho public morpho;

    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    function setUp() public {
        MarketParams memory marketParams = MarketParams({
            loanToken: address(debtToken),
            collateralToken: address(collateralToken),
            oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as calls to morpho are mocked
            irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as calls to morpho are mocked
            lltv: 1e18 // 100%, doesn't matter for these tests as calls to morpho are mocked
        });

        // Mocked Morpho protocol is setup with a market with id 1
        morpho = new MockMorpho(Id.wrap(bytes32("1")), marketParams);

        lendingAdapter = new MorphoLendingAdapter();
    }

    function testFuzz_initialize(bytes32 marketId) public {
        vm.expectEmit(true, true, true, true);
        emit IMorphoLendingAdapter.Initialized(IMorpho(address(morpho)), Id.wrap(marketId));
        lendingAdapter.initialize(IMorpho(address(morpho)), Id.wrap(marketId));

        assertEq(address(lendingAdapter.morpho()), address(morpho));
        assertEq(abi.encode(lendingAdapter.marketId()), abi.encode(marketId));
    }

    function test_initialize_RevertIf_Initialized() public {
        lendingAdapter.initialize(IMorpho(address(morpho)), Id.wrap(bytes32("1")));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        lendingAdapter.initialize(IMorpho(address(morpho)), Id.wrap(bytes32("1")));
    }
}
