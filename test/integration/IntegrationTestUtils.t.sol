// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IMorpho, Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IVeloraAdapter} from "src/interfaces/periphery/IVeloraAdapter.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {LeverageTokenConfig} from "src/types/DataTypes.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {MorphoLendingAdapterFactory} from "src/lending/MorphoLendingAdapterFactory.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {MulticallExecutor} from "src/periphery/MulticallExecutor.sol";
import {VeloraAdapter} from "src/periphery/VeloraAdapter.sol";

contract IntegrationTestUtils is Test {
    uint256 public constant BASE_RATIO = 1e18;
    uint256 public constant SECONDS_ONE_YEAR = 31536000;

    address public user = makeAddr("user");
    address public treasury = makeAddr("treasury");

    RebalanceAdapter rebalanceAdapterImplementation;

    ILeverageToken public leverageToken;
    IMorphoLendingAdapterFactory public morphoLendingAdapterFactory;
    ILeverageManager public leverageManager;
    IVeloraAdapter public veloraAdapter;
    MorphoLendingAdapter public morphoLendingAdapter;
    RebalanceAdapter public rebalanceAdapter;
    MulticallExecutor public multicallExecutor;

    function _createNewLeverageToken(
        uint256 minColRatio,
        uint256 targetCollateralRatio,
        uint256 maxColRatio,
        uint256 mintFee,
        uint256 redeemFee,
        Id morphoMarketId
    ) internal virtual returns (ILeverageToken) {
        ILendingAdapter lendingAdapter = ILendingAdapter(
            morphoLendingAdapterFactory.deployAdapter(morphoMarketId, address(this), bytes32(vm.randomUint()))
        );

        address _rebalanceAdapter = address(
            _deployRebalanceAdapter(
                minColRatio, targetCollateralRatio, maxColRatio, 7 minutes, 1.2 * 1e18, 0.9 * 1e18, 1.1e18, 40_00
            )
        );

        ILeverageToken _leverageToken = leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: lendingAdapter,
                rebalanceAdapter: IRebalanceAdapter(_rebalanceAdapter),
                mintTokenFee: mintFee,
                redeemTokenFee: redeemFee
            }),
            "dummy name",
            "dummy symbol"
        );

        return _leverageToken;
    }

    function _deployRebalanceAdapter(
        uint256 minCollateralRatio,
        uint256 targetCollateralRatio,
        uint256 maxCollateralRatio,
        uint120 auctionDuration,
        uint256 initialPriceMultiplier,
        uint256 minPriceMultiplier,
        uint256 collateralRatioThreshold,
        uint256 rebalanceReward
    ) internal returns (RebalanceAdapter) {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(rebalanceAdapterImplementation),
            abi.encodeWithSelector(
                RebalanceAdapter.initialize.selector,
                RebalanceAdapter.RebalanceAdapterInitParams({
                    owner: address(this),
                    authorizedCreator: address(this),
                    leverageManager: leverageManager,
                    minCollateralRatio: minCollateralRatio,
                    targetCollateralRatio: targetCollateralRatio,
                    maxCollateralRatio: maxCollateralRatio,
                    auctionDuration: auctionDuration,
                    initialPriceMultiplier: initialPriceMultiplier,
                    minPriceMultiplier: minPriceMultiplier,
                    preLiquidationCollateralRatioThreshold: collateralRatioThreshold,
                    rebalanceReward: rebalanceReward
                })
            )
        );

        return RebalanceAdapter(address(proxy));
    }

    function _deployIntegrationTestContracts(IMorpho morpho, Id morphoMarketId, address augustusRegistry) internal {
        LeverageToken leverageTokenImplementation = new LeverageToken();
        BeaconProxyFactory leverageTokenFactory =
            new BeaconProxyFactory(address(leverageTokenImplementation), address(this));

        address leverageManagerImplementation = address(new LeverageManagerHarness());
        leverageManager = ILeverageManager(
            UnsafeUpgrades.deployUUPSProxy(
                leverageManagerImplementation,
                abi.encodeWithSelector(
                    LeverageManager.initialize.selector, address(this), treasury, leverageTokenFactory
                )
            )
        );
        LeverageManager(address(leverageManager)).grantRole(keccak256("FEE_MANAGER_ROLE"), address(this));

        MorphoLendingAdapter morphoLendingAdapterImplementation =
            new MorphoLendingAdapter(ILeverageManager(leverageManager), morpho);

        morphoLendingAdapterFactory = new MorphoLendingAdapterFactory(morphoLendingAdapterImplementation);

        morphoLendingAdapter = MorphoLendingAdapter(
            address(morphoLendingAdapterFactory.deployAdapter(morphoMarketId, address(this), bytes32(0)))
        );

        rebalanceAdapterImplementation = new RebalanceAdapter();
        rebalanceAdapter = _deployRebalanceAdapter(1.5e18, 2e18, 2.5e18, 7 minutes, 1.2e18, 0.9e18, 1.2e18, 40_00);

        multicallExecutor = new MulticallExecutor();

        veloraAdapter = new VeloraAdapter(augustusRegistry);

        leverageToken = leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(morphoLendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(address(rebalanceAdapter)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            "Leverage Token Name",
            "Leverage Token Symbol"
        );

        vm.label(address(user), "user");
        vm.label(address(treasury), "treasury");
        vm.label(address(leverageToken), "leverageToken");
        vm.label(address(morphoLendingAdapter), "morphoLendingAdapter");
        vm.label(address(morpho), "morpho");
        vm.label(address(leverageManager), "leverageManager");
        vm.label(address(multicallExecutor), "multicallExecutor");
        vm.label(address(veloraAdapter), "veloraAdapter");
    }
}
