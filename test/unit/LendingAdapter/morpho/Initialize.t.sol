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

    MarketParams public defaultMarketParams;

    function setUp() public {
        defaultMarketParams = MarketParams({
            loanToken: address(debtToken),
            collateralToken: address(collateralToken),
            oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as calls to morpho are mocked
            irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as calls to morpho are mocked
            lltv: 1e18 // 100%, doesn't matter for these tests as calls to morpho are mocked
        });

        // Mocked Morpho protocol is setup with a market with id 1
        morpho = new MockMorpho(Id.wrap(bytes32("1")), defaultMarketParams);

        lendingAdapter = new MorphoLendingAdapter();
    }

    function testFuzz_initialize(MarketParams memory _marketParams) public {
        vm.expectEmit(true, true, true, true);
        emit IMorphoLendingAdapter.Initialized(IMorpho(address(morpho)), _marketParams);
        lendingAdapter.initialize(IMorpho(address(morpho)), _marketParams);

        assertEq(address(lendingAdapter.morpho()), address(morpho));

        (address loanToken, address _collateralToken, address oracle, address irm, uint256 lltv) =
            lendingAdapter.marketParams();
        assertEq(loanToken, _marketParams.loanToken);
        assertEq(_collateralToken, _marketParams.collateralToken);
        assertEq(oracle, _marketParams.oracle);
        assertEq(irm, _marketParams.irm);
        assertEq(lltv, _marketParams.lltv);
    }

    function test_initialize_RevertIf_Initialized() public {
        lendingAdapter.initialize(IMorpho(address(morpho)), defaultMarketParams);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        lendingAdapter.initialize(IMorpho(address(morpho)), defaultMarketParams);
    }
}
