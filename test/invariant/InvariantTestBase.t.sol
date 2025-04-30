// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {ExternalAction, LeverageTokenConfig} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";

abstract contract InvariantTestBase is Test {
    uint256 public BASE_RATIO;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");
    address public feeManagerRole = makeAddr("feeManagerRole");

    LeverageManagerHarness public leverageManager;
    LeverageManagerHandler public leverageManagerHandler;

    RebalanceAdapter public rebalanceAdapterImplementation;

    function setUp() public {
        address leverageTokenImplementation = address(new LeverageToken());

        BeaconProxyFactory leverageTokenFactory = new BeaconProxyFactory(leverageTokenImplementation, address(this));
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            leverageManagerImplementation,
            abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin, address(leverageTokenFactory))
        );
        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        rebalanceAdapterImplementation = new RebalanceAdapter();

        vm.startPrank(defaultAdmin);
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), feeManagerRole);
        vm.stopPrank();

        BASE_RATIO = leverageManager.BASE_RATIO();

        _initLeverageManagerHandler(leverageManager);

        targetContract(address(leverageManagerHandler));
        targetSelector(FuzzSelector({addr: address(leverageManagerHandler), selectors: _fuzzedSelectors()}));
    }

    function _deployRebalanceAdapter(RebalanceAdapter.RebalanceAdapterInitParams memory initParams)
        internal
        returns (RebalanceAdapter)
    {
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(rebalanceAdapterImplementation),
            abi.encodeWithSelector(RebalanceAdapter.initialize.selector, initParams)
        );

        return RebalanceAdapter(address(proxy));
    }

    function _createActors(uint256 numActors) internal returns (address[] memory) {
        address[] memory actors = new address[](numActors);
        for (uint256 i = 0; i < numActors; i++) {
            actors[i] = makeAddr(string.concat("actor-", Strings.toString(i)));
        }
        return actors;
    }

    function _fuzzedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = LeverageManagerHandler.mint.selector;
        selectors[1] = LeverageManagerHandler.redeem.selector;
        selectors[2] = LeverageManagerHandler.addCollateral.selector;
        selectors[3] = LeverageManagerHandler.repayDebt.selector;
        selectors[4] = LeverageManagerHandler.updateOraclePrice.selector;
        return selectors;
    }

    function _initLeverageManagerHandler(LeverageManagerHarness _leverageManager) internal {
        ILeverageToken[] memory leverageTokens = new ILeverageToken[](1);
        leverageTokens[0] = _initLeverageToken(
            "Strategy A",
            "STRAT-A",
            1_00,
            1_00,
            RebalanceAdapter.RebalanceAdapterInitParams({
                owner: address(this),
                authorizedCreator: address(this),
                leverageManager: leverageManager,
                minCollateralRatio: 1 * BASE_RATIO,
                targetCollateralRatio: 2 * BASE_RATIO,
                maxCollateralRatio: 3 * BASE_RATIO,
                auctionDuration: 10 minutes,
                initialPriceMultiplier: 1.05e18, // 105%
                minPriceMultiplier: 0.9e18, // 90%
                preLiquidationCollateralRatioThreshold: 102e18, // 102%
                rebalanceReward: 5_00 // 5%
            })
        );

        address[] memory actors = _createActors(10);

        leverageManagerHandler = new LeverageManagerHandler(_leverageManager, leverageTokens, actors);

        vm.label(address(leverageManagerHandler), "leverageManagerHandler");
    }

    function _initLeverageToken(
        string memory name,
        string memory symbol,
        uint256 mintTokenFee,
        uint256 redeemTokenFee,
        RebalanceAdapter.RebalanceAdapterInitParams memory initParams
    ) internal returns (ILeverageToken leverageToken) {
        MockERC20 collateralAsset = new MockERC20();
        MockERC20 debtAsset = new MockERC20();

        MockLendingAdapter lendingAdapter =
            new MockLendingAdapter(address(collateralAsset), address(debtAsset), address(this));

        IRebalanceAdapterBase rebalanceAdapter = _deployRebalanceAdapter(initParams);

        vm.mockCall(
            address(rebalanceAdapter),
            abi.encodeWithSelector(IRebalanceAdapterBase.postLeverageTokenCreation.selector),
            abi.encode(true)
        );

        LeverageTokenConfig memory config = LeverageTokenConfig({
            lendingAdapter: ILendingAdapter(address(lendingAdapter)),
            rebalanceAdapter: rebalanceAdapter,
            mintTokenFee: mintTokenFee,
            redeemTokenFee: redeemTokenFee
        });

        return leverageManager.createNewLeverageToken(config, name, symbol);
    }

    function _setTreasuryActionFee(ExternalAction action, uint128 newTreasuryFee) internal {
        vm.prank(feeManagerRole);
        leverageManager.setTreasuryActionFee(action, newTreasuryFee);
    }

    function _setManagementFee(uint128 newManagementFee) internal {
        vm.prank(feeManagerRole);
        leverageManager.setManagementFee(newManagementFee);
    }
}
