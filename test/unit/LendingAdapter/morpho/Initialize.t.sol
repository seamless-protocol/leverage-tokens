// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Id, MarketParams, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {MorphoLendingAdapterTest} from "./MorphoLendingAdapter.t.sol";
import {MockMorpho} from "../../mock/MockMorpho.sol";

contract MorphoLendingAdapterInitializeTest is MorphoLendingAdapterTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_initialize(Id marketId, MarketParams memory marketParams) public {
        morpho.mockSetMarketParams(marketId, marketParams);

        // Mock the calls to get the decimals of the loan token and collateral token in the initialize function. Not important
        // for the test, but reverts if not mocked
        vm.mockCall(
            address(marketParams.loanToken), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(18)
        );
        vm.mockCall(
            address(marketParams.collateralToken),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );

        MorphoLendingAdapter _lendingAdapter = new MorphoLendingAdapter(leverageManager, IMorpho(address(morpho)));
        assertEq(address(_lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(_lendingAdapter.morpho()), address(morpho));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        _lendingAdapter.initialize(marketId, authorizedCreator);

        assertEq(address(_lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(_lendingAdapter.morpho()), address(morpho));

        (address loanToken, address _collateralToken, address oracle, address irm, uint256 lltv) =
            _lendingAdapter.marketParams();
        assertEq(loanToken, marketParams.loanToken);
        assertEq(_collateralToken, marketParams.collateralToken);
        assertEq(oracle, marketParams.oracle);
        assertEq(irm, marketParams.irm);
        assertEq(lltv, marketParams.lltv);
        assertEq(_lendingAdapter.authorizedCreator(), authorizedCreator);
    }

    function test_initialize_RevertIf_Initialized() public {
        MorphoLendingAdapter _lendingAdapter = new MorphoLendingAdapter(leverageManager, IMorpho(address(morpho)));
        _lendingAdapter.initialize(defaultMarketId, authorizedCreator);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        _lendingAdapter.initialize(defaultMarketId, authorizedCreator);
    }

    function test_initialize_UsingBeaconProxy() public {
        UpgradeableBeacon morphoLendingAdapterBeacon = new UpgradeableBeacon(address(lendingAdapter), address(this));
        assertEq(address(morphoLendingAdapterBeacon.implementation()), address(lendingAdapter));

        // Mock the calls to get the decimals of the loan token and collateral token in the initialize function. Not important
        // for the test, but reverts if not mocked
        vm.mockCall(
            address(defaultMarketParams.loanToken),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            address(defaultMarketParams.collateralToken),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );

        // Create a beacon proxy and assert that the market params are set correctly but the immutable leverage manager
        // and morpho addresses are the same as the beacon
        IMorphoLendingAdapter morphoLendingAdapterProxy = IMorphoLendingAdapter(
            address(
                new BeaconProxy(
                    address(morphoLendingAdapterBeacon),
                    abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, defaultMarketId, authorizedCreator)
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
        assertEq(morphoLendingAdapterProxy.authorizedCreator(), authorizedCreator);

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

        // Mock the calls to get the decimals of the loan token and collateral token in the initialize function. Not important
        // for the test, but reverts if not mocked
        vm.mockCall(
            address(otherMarketParams.loanToken),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            address(otherMarketParams.collateralToken),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );
        morphoLendingAdapterProxy = IMorphoLendingAdapter(
            address(
                new BeaconProxy(
                    address(morphoLendingAdapterBeacon),
                    abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, marketId, authorizedCreator)
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
        assertEq(morphoLendingAdapterProxy.authorizedCreator(), authorizedCreator);
    }
}
