// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {IEtherFiL2ModeSyncPool} from "src/interfaces/periphery/IEtherFiL2ModeSyncPool.sol";
import {IEtherFiLeverageRouter} from "src/interfaces/periphery/IEtherFiLeverageRouter.sol";
import {EtherFiLeverageRouter} from "src/periphery/EtherFiLeverageRouter.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {LeverageTokenConfig} from "src/types/DataTypes.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";

contract EtherFiLeverageRouterTest is IntegrationTestBase {
    IERC20 public constant WEETH = IERC20(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A);

    IEtherFiL2ModeSyncPool public constant etherFiL2ModeSyncPool =
        IEtherFiL2ModeSyncPool(0xc38e046dFDAdf15f7F56853674242888301208a5);

    IEtherFiLeverageRouter public leverageRouter;

    Id public constant WEETH_WETH_MARKET_ID =
        Id.wrap(0x78d11c03944e0dc298398f0545dc8195ad201a18b0388cb8058b1bcb89440971);

    function setUp() public virtual override {
        super.setUp();

        morphoLendingAdapter = MorphoLendingAdapter(
            address(morphoLendingAdapterFactory.deployAdapter(WEETH_WETH_MARKET_ID, address(this), bytes32("1")))
        );

        rebalanceAdapterImplementation = new RebalanceAdapter();
        rebalanceAdapter = _deployRebalanceAdapter(1.5e18, 2e18, 2.5e18, 7 minutes, 1.2e18, 0.9e18, 1.2e18, 40_00);

        leverageToken = leverageManager.createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(morphoLendingAdapter)),
                rebalanceAdapter: IRebalanceAdapter(address(rebalanceAdapter)),
                mintTokenFee: 0,
                redeemTokenFee: 0
            }),
            "Seamless WEETH/WETH 2x leverage token",
            "ltWEETH/WETH-2x"
        );

        leverageRouter = new EtherFiLeverageRouter(leverageManager, MORPHO, etherFiL2ModeSyncPool);

        vm.label(address(leverageRouter), "leverageRouter");
        vm.label(address(etherFiL2ModeSyncPool), "etherFiL2ModeSyncPool");
    }

    function testFork_setUp() public view virtual override {
        assertEq(address(leverageManager.getLeverageTokenCollateralAsset(leverageToken)), address(WEETH));
        assertEq(address(leverageManager.getLeverageTokenDebtAsset(leverageToken)), address(WETH));

        assertEq(address(leverageRouter.leverageManager()), address(leverageManager));
        assertEq(address(leverageRouter.morpho()), address(MORPHO));
        assertEq(address(leverageRouter.etherFiL2ModeSyncPool()), address(etherFiL2ModeSyncPool));
    }

    function _dealAndMint(IERC20 collateralAsset, uint256 dealAmount, uint256 equityInCollateralAsset) internal {
        deal(address(collateralAsset), user, dealAmount);

        vm.startPrank(user);
        collateralAsset.approve(address(leverageRouter), equityInCollateralAsset);
        leverageRouter.mint(leverageToken, equityInCollateralAsset, 0);
        vm.stopPrank();

        // No leftover assets in the LeverageRouter
        assertEq(collateralAsset.balanceOf(address(leverageRouter)), 0);
    }
}
