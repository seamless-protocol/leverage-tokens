// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {Id, MarketParams, IMorpho} from "src/interfaces/IMorpho.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";

contract MorphoLendingAdapterInitializeTest is Test {
    function testFuzz_initialize(ILeverageManager leverageManager, IMorpho _morpho, MarketParams memory marketParams)
        public
    {
        MorphoLendingAdapter lendingAdapter = new MorphoLendingAdapter(leverageManager, _morpho);
        assertEq(address(lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(lendingAdapter.morpho()), address(_morpho));

        vm.expectEmit(true, true, true, true);
        emit IMorphoLendingAdapter.Initialized(marketParams);
        lendingAdapter.initialize(marketParams);

        assertEq(address(lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(lendingAdapter.morpho()), address(_morpho));

        (address loanToken, address _collateralToken, address oracle, address irm, uint256 lltv) =
            lendingAdapter.marketParams();
        assertEq(loanToken, marketParams.loanToken);
        assertEq(_collateralToken, marketParams.collateralToken);
        assertEq(oracle, marketParams.oracle);
        assertEq(irm, marketParams.irm);
        assertEq(lltv, marketParams.lltv);
    }

    function test_initialize_RevertIf_Initialized() public {
        MarketParams memory marketParams = MarketParams({
            loanToken: makeAddr("loanToken"), // doesn't matter for these tests as there are no calls to morpho
            collateralToken: makeAddr("collateralToken"), // doesn't matter for these tests as there are no calls to morpho
            oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as there are no calls to morpho
            irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as there are no calls to morpho
            lltv: 1e18 // 100%, doesn't matter for these tests as there are no calls to morpho
        });

        ILeverageManager leverageManager = ILeverageManager(makeAddr("leverageManager"));
        IMorpho morpho = IMorpho(makeAddr("morpho"));
        MorphoLendingAdapter lendingAdapter = new MorphoLendingAdapter(leverageManager, morpho);

        lendingAdapter.initialize(marketParams);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        lendingAdapter.initialize(marketParams);
    }
}
