// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";

contract IntegrationTestBase is Test {
    IERC20 public WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 public USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IMorpho public MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    Id public WETH_USDC_MARKET_ID = Id.wrap(0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda);

    ILeverageManager public leverageManager = ILeverageManager(makeAddr("leverageManager"));
    MorphoLendingAdapter public morphoLendingAdapter;

    function setUp() public virtual {
        uint256 forkId = vm.createFork(vm.envString("BASE_RPC_URL"));
        vm.selectFork(forkId);
        vm.rollFork(25473904);

        MorphoLendingAdapter morphoLendingAdapterImplementation =
            new MorphoLendingAdapter(ILeverageManager(leverageManager), MORPHO);

        BeaconProxyFactory morphoLendingAdapterFactory =
            new BeaconProxyFactory(address(morphoLendingAdapterImplementation), address(this));

        morphoLendingAdapter = MorphoLendingAdapter(
            morphoLendingAdapterFactory.createProxy(
                abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, WETH_USDC_MARKET_ID), bytes32(0)
            )
        );
    }

    function testFork_setUp() public view virtual {
        assertEq(address(morphoLendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(morphoLendingAdapter.morpho()), address(MORPHO));
        assertEq(address(morphoLendingAdapter.getCollateralAsset()), address(WETH));
        assertEq(address(morphoLendingAdapter.getDebtAsset()), address(USDC));

        assertEq(morphoLendingAdapter.getCollateral(), 0);
        assertEq(morphoLendingAdapter.getCollateralInDebtAsset(), 0);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), 0);
        assertEq(morphoLendingAdapter.getEquityInDebtAsset(), 0);
    }
}
