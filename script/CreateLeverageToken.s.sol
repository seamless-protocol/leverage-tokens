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
import {DeployConstants} from "./DeployConstants.sol";

contract CreateLeverageToken is Script {
    ILeverageManager public leverageManager = ILeverageManager(DeployConstants.LEVERAGE_MANAGER);
    IMorphoLendingAdapterFactory public lendingAdapterFactory =
        IMorphoLendingAdapterFactory(DeployConstants.LENDING_ADAPTER_FACTORY);

    Id public MORPHO_MARKET_ID = Id.wrap(0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda);
    bytes32 public BASE_SALT = bytes32(uint256(0));

    uint256 public MIN_COLLATERAL_RATIO = 1.8e18;
    uint256 public TARGET_COLLATERAL_RATIO = 2e18;
    uint256 public MAX_COLLATERAL_RATIO = 2.2e18;
    uint256 public AUCTION_DURATION = 1 minutes;
    uint256 public INITIAL_PRICE_MULTIPLIER = 1.02e18;
    uint256 public MIN_PRICE_MULTIPLIER = 0.98e18;
    uint256 public PRE_LIQUIDATION_COLLATERAL_RATIO_THRESHOLD = 1.3e18;
    uint256 public REBALANCE_REWARD = 50_00;

    uint256 public MINT_TOKEN_FEE = 1;
    uint256 public REDEEM_TOKEN_FEE = 1;

    string public LT_NAME = "NAME";
    string public LT_SYMBOL = "SYMBOL";

    function run() public {
        address deployerAddress = msg.sender;

        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);
        console.log("DeployerAddress: ", deployerAddress);

        console.log("Deploying...");

        vm.startBroadcast();


        RebalanceAdapter rebalanceAdapter = new RebalanceAdapter();
        console.log("RebalanceAdapter deployed at: ", address(rebalanceAdapter));

        ERC1967Proxy rebalanceAdapterProxy = new ERC1967Proxy(
            address(rebalanceAdapter),
            abi.encodeWithSelector(
                RebalanceAdapter.initialize.selector,
                DeployConstants.SEAMLESS_GOVERNOR_SHORT,
                deployerAddress,
                leverageManager,
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

        IMorphoLendingAdapter lendingAdapter =
            lendingAdapterFactory.deployAdapter(MORPHO_MARKET_ID, deployerAddress, BASE_SALT);
        console.log("LendingAdapter deployed at: ", address(lendingAdapter));

        ILeverageToken leverageToken = leverageManager.createNewLeverageToken(
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
