// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {Id, MarketParams, IMorpho} from "src/interfaces/IMorpho.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {MockMorpho} from "../../mock/MockMorpho.sol";

contract MorphoLendingAdapterInitializeTest is Test {
    MorphoLendingAdapter public lendingAdapter;
    MockMorpho public morpho;

    ERC20Mock public collateralToken = new ERC20Mock();
    ERC20Mock public debtToken = new ERC20Mock();

    MarketParams public marketParams;

    function setUp() public {
        marketParams = MarketParams({
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
        emit IMorphoLendingAdapter.Initialized(IMorpho(address(morpho)), marketParams);
        lendingAdapter.initialize(IMorpho(address(morpho)), marketParams);

        assertEq(address(lendingAdapter.morpho()), address(morpho));

        (address loanToken, address _collateralToken, address oracle, address irm, uint256 lltv) =
            lendingAdapter.marketParams();
        assertEq(loanToken, marketParams.loanToken);
        assertEq(_collateralToken, marketParams.collateralToken);
        assertEq(oracle, marketParams.oracle);
        assertEq(irm, marketParams.irm);
        assertEq(lltv, marketParams.lltv);
    }

    function test_initialize_RevertIf_Initialized() public {
        lendingAdapter.initialize(IMorpho(address(morpho)), marketParams);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        lendingAdapter.initialize(IMorpho(address(morpho)), marketParams);
    }
}
