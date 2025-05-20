// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {LeverageTokenConfig} from "src/types/DataTypes.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {DeployConstants} from "./DeployConstants.sol";
import {MorphoLendingAdapterFactory} from "src/lending/MorphoLendingAdapterFactory.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";

contract FullDeploy is Script {
    Id public MORPHO_MARKET_ID = Id.wrap(0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda);
    bytes32 public BASE_SALT = bytes32(uint256(0));

    uint256 public MIN_COLLATERAL_RATIO = 1.8e18;
    uint256 public TARGET_COLLATERAL_RATIO = 2e18;
    uint256 public MAX_COLLATERAL_RATIO = 2.2e18;
    uint256 public AUCTION_DURATION = 1 minutes;
    uint256 public INITIAL_PRICE_MULTIPLIER = 1.02e18;
    uint256 public MIN_PRICE_MULTIPLIER = 0.98e18;
    uint256 public PRE_LIQUIDATION_COLLATERAL_RATIO_THRESHOLD = type(uint256).max;
    uint256 public REBALANCE_REWARD = 50_00;

    uint256 public MINT_TOKEN_FEE = 1;
    uint256 public REDEEM_TOKEN_FEE = 1;

    string public LT_NAME = "NAME";
    string public LT_SYMBOL = "SYMBOL";

    function run() public {
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        console.log("Deploying...");

        vm.startBroadcast();

        address deployerAddress = msg.sender;

        // Deploy leverage token factory that is used by LM
        LeverageToken leverageTokenImplementation = new LeverageToken();
        console.log("LeverageToken implementation deployed at: ", address(leverageTokenImplementation));

        BeaconProxyFactory leverageTokenFactory =
            new BeaconProxyFactory(address(leverageTokenImplementation), deployerAddress);
        console.log("LeverageToken factory deployed at: ", address(leverageTokenFactory));

        // Deploy LM
        LeverageManager leverageManagerImplementation = new LeverageManager();
        console.log("LeverageManager implementation deployed at: ", address(leverageManagerImplementation));

        ERC1967Proxy leverageManagerProxy = new ERC1967Proxy(
            address(leverageManagerImplementation),
            abi.encodeWithSelector(
                LeverageManager.initialize.selector, deployerAddress, deployerAddress, leverageTokenFactory
            )
        );
        console.log("LeverageManager proxy deployed at: ", address(leverageManagerProxy));

        // Deploy Morpho LA factory
        MorphoLendingAdapter lendingAdapterImplementation =
            new MorphoLendingAdapter(ILeverageManager(address(leverageManagerProxy)), IMorpho(DeployConstants.MORPHO));
        console.log("LendingAdapter implementation deployed at: ", address(lendingAdapterImplementation));

        MorphoLendingAdapterFactory lendingAdapterFactory =
            new MorphoLendingAdapterFactory(lendingAdapterImplementation);
        console.log("LendingAdapterFactory deployed at: ", address(lendingAdapterFactory));

        // Deploy SwapAdapter
        SwapAdapter swapAdapter = new SwapAdapter();
        console.log("SwapAdapter deployed at: ", address(swapAdapter));

        // Deploy LeverageRouter
        LeverageRouter leverageRouter = new LeverageRouter(
            ILeverageManager(DeployConstants.LEVERAGE_MANAGER),
            IMorpho(DeployConstants.MORPHO),
            ISwapAdapter(swapAdapter)
        );
        console.log("LeverageRouter deployed at: ", address(leverageRouter));

        // Deploy RebalanceAdapter and initialize it
        RebalanceAdapter rebalanceAdapter = new RebalanceAdapter();
        console.log("RebalanceAdapter deployed at: ", address(rebalanceAdapter));

        ERC1967Proxy rebalanceAdapterProxy = new ERC1967Proxy(
            address(rebalanceAdapter),
            abi.encodeWithSelector(
                RebalanceAdapter.initialize.selector,
                DeployConstants.SEAMLESS_GOVERNOR_SHORT,
                deployerAddress,
                ILeverageManager(address(leverageManagerProxy)),
                MIN_COLLATERAL_RATIO,
                TARGET_COLLATERAL_RATIO,
                MAX_COLLATERAL_RATIO,
                AUCTION_DURATION,
                INITIAL_PRICE_MULTIPLIER,
                MIN_PRICE_MULTIPLIER,
                PRE_LIQUIDATION_COLLATERAL_RATIO_THRESHOLD,
                REBALANCE_REWARD
            )
        );
        console.log("RebalanceAdapter proxy deployed at: ", address(rebalanceAdapterProxy));

        // Deploy LA and initialize it
        IMorphoLendingAdapter lendingAdapter =
            lendingAdapterFactory.deployAdapter(MORPHO_MARKET_ID, deployerAddress, BASE_SALT);
        console.log("LendingAdapter deployed at: ", address(lendingAdapter));

        // Deploy LT
        ILeverageToken leverageToken = ILeverageManager(address(leverageManagerProxy)).createNewLeverageToken(
            LeverageTokenConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                rebalanceAdapter: IRebalanceAdapterBase(address(rebalanceAdapterProxy)),
                mintTokenFee: MINT_TOKEN_FEE,
                redeemTokenFee: REDEEM_TOKEN_FEE
            }),
            LT_NAME,
            LT_SYMBOL
        );

        console.log("LeverageToken deployed at: ", address(leverageToken));

        vm.stopBroadcast();
    }
}
