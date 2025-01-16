// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Id, MarketParams, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";
import {MockMorpho} from "../../mock/MockMorpho.sol";

contract MorphoLendingAdapterInitializeTest is MorphoLendingAdapterBaseTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_initialize(Id marketId, MarketParams memory marketParams) public {
        morpho.mockSetMarketParams(marketId, marketParams);

        MorphoLendingAdapter _lendingAdapter = new MorphoLendingAdapter(leverageManager, IMorpho(address(morpho)));
        assertEq(address(_lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(_lendingAdapter.morpho()), address(morpho));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        _lendingAdapter.initialize(marketId);

        assertEq(address(_lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(_lendingAdapter.morpho()), address(morpho));

        (address loanToken, address _collateralToken, address oracle, address irm, uint256 lltv) =
            _lendingAdapter.marketParams();
        assertEq(loanToken, marketParams.loanToken);
        assertEq(_collateralToken, marketParams.collateralToken);
        assertEq(oracle, marketParams.oracle);
        assertEq(irm, marketParams.irm);
        assertEq(lltv, marketParams.lltv);
    }

    function test_initialize_RevertIf_Initialized() public {
        MorphoLendingAdapter _lendingAdapter = new MorphoLendingAdapter(leverageManager, IMorpho(address(morpho)));
        _lendingAdapter.initialize(defaultMarketId);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        _lendingAdapter.initialize(defaultMarketId);
    }

    function test_initialize_UsingBeaconProxy() public {
        UpgradeableBeacon morphoLendingAdapterBeacon = new UpgradeableBeacon(address(lendingAdapter), address(this));
        assertEq(address(morphoLendingAdapterBeacon.implementation()), address(lendingAdapter));

        // Create a beacon proxy and assert that the market params are set correctly but the immutable leverage manager
        // and morpho addresses are the same as the beacon
        IMorphoLendingAdapter morphoLendingAdapterProxy = IMorphoLendingAdapter(
            address(
                new BeaconProxy(
                    address(morphoLendingAdapterBeacon),
                    abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, defaultMarketId)
                )
            )
        );
        assertEq(address(morphoLendingAdapterProxy.leverageManager()), address(leverageManager));
        assertEq(address(morphoLendingAdapterProxy.morpho()), address(morpho));
        (address loanToken, address _collateralToken, address oracle, address irm, uint256 lltv) =
            morphoLendingAdapterProxy.marketParams();
        assertEq(loanToken, defaultMarketParams.loanToken);
        assertEq(_collateralToken, defaultMarketParams.collateralToken);
        assertEq(oracle, defaultMarketParams.oracle);
        assertEq(irm, defaultMarketParams.irm);
        assertEq(lltv, defaultMarketParams.lltv);

        // Create another beacon proxy with different market params, asserting that the market params are different but
        // the immutable leverage manager and morpho addresses are the same as the beacon
        Id marketId = Id.wrap("0xBEEF");
        MarketParams memory otherMarketParams = MarketParams({
            loanToken: makeAddr("loanToken"),
            collateralToken: makeAddr("collateralToken"),
            oracle: makeAddr("oracle"),
            irm: makeAddr("irm"),
            lltv: 10000
        });
        morpho.mockSetMarketParams(marketId, otherMarketParams);
        morphoLendingAdapterProxy = IMorphoLendingAdapter(
            address(
                new BeaconProxy(
                    address(morphoLendingAdapterBeacon),
                    abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, marketId)
                )
            )
        );
        assertEq(address(morphoLendingAdapterProxy.leverageManager()), address(leverageManager));
        assertEq(address(morphoLendingAdapterProxy.morpho()), address(morpho));
        (address otherLoanToken, address otherCollateralToken, address otherOracle, address otherIrm, uint256 otherLltv)
        = morphoLendingAdapterProxy.marketParams();
        assertEq(otherLoanToken, otherMarketParams.loanToken);
        assertEq(otherCollateralToken, otherMarketParams.collateralToken);
        assertEq(otherOracle, otherMarketParams.oracle);
        assertEq(otherIrm, otherMarketParams.irm);
        assertEq(otherLltv, otherMarketParams.lltv);
    }
}
