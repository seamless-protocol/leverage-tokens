// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPreLiquidationRebalanceAdapter} from "src/interfaces/IPreLiquidationRebalanceAdapter.sol";
import {ICollateralRatiosRebalanceAdapter} from "src/interfaces/ICollateralRatiosRebalanceAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {ActionData} from "src/types/DataTypes.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {DeployConstants} from "./DeployConstants.sol";
import {ILeverageTokenDeploymentBatcher} from "src/interfaces/periphery/ILeverageTokenDeploymentBatcher.sol";

contract CreateLeverageToken is Script {
    uint256 public constant WAD = 1e18;

    ILeverageManager public leverageManager = ILeverageManager(DeployConstants.LEVERAGE_MANAGER);
    IMorphoLendingAdapterFactory public lendingAdapterFactory =
        IMorphoLendingAdapterFactory(DeployConstants.LENDING_ADAPTER_FACTORY);

    ILeverageTokenDeploymentBatcher public leverageTokenDeploymentBatcher =
        ILeverageTokenDeploymentBatcher(DeployConstants.LEVERAGE_TOKEN_DEPLOYMENT_BATCHER);

    /// @dev Market ID for Morpho market that LT will be created on top of
    Id public MORPHO_MARKET_ID = Id.wrap(0xbbf7ce1b40d32d3e3048f5cf27eeaa6de8cb27b80194690aab191a63381d8c99);
    /// @dev Salt that will be used to deploy the lending adapter. Should be unique for deployer. Update after each deployment.
    bytes32 public BASE_SALT = bytes32(vm.randomUint());

    /// @dev Minimum collateral ratio for the LT on 18 decimals
    uint256 public MIN_COLLATERAL_RATIO = 1.095238095e18;
    /// @dev Target collateral ratio for the LT on 18 decimals
    uint256 public TARGET_COLLATERAL_RATIO = 1.1e18;
    /// @dev Maximum collateral ratio for the LT on 18 decimals
    uint256 public MAX_COLLATERAL_RATIO = 1.101010101e18;
    /// @dev Duration of the dutch auction for the LT
    uint120 public AUCTION_DURATION = 1 hours;
    /// @dev Initial oracle price multiplier on Dutch auction on 18 decimals. In percentage.
    uint256 public INITIAL_PRICE_MULTIPLIER = 1.001e18;
    /// @dev Minimum oracle price multiplier on Dutch auction on 18 decimals. In percentage.
    uint256 public MIN_PRICE_MULTIPLIER = 0.999e18;
    /// @dev Collateral ratio threshold for the pre-liquidation rebalance adapter
    /// @dev When collateral ratio falls below this value, rebalance adapter will allow rebalance without Dutch auction for special premium
    uint256 public PRE_LIQUIDATION_COLLATERAL_RATIO_THRESHOLD = 1.094073377e18;
    /// @dev Rebalance reward for the rebalance adapter, 100% = 10000
    /// @dev Represents reward for pre liquidation rebalance, relative to the liquidation penalty. 50_00 means 50% of liquidation penalty
    /// @dev Liquidation penalty is relative to the lltv on Morpho market.
    uint256 public REBALANCE_REWARD = 50_00;

    /// @dev Token fee when minting. 100% = 10000
    uint256 public MINT_TOKEN_FEE = 0;
    /// @dev Token fee when redeeming. 100% = 10000
    uint256 public REDEEM_TOKEN_FEE = 0;

    /// @dev Name of the LT
    string public LT_NAME = "siUSD / USDC 11x Leverage Token";
    /// @dev Symbol of the LT
    string public LT_SYMBOL = "SIUSD-USDC-11x";

    /// @dev Initial collateral deposit for the LT
    uint256 public INITIAL_COLLATERAL_DEPOSIT = 0.001 * 1e18;
    uint256 public INITIAL_COLLATERAL_DEPOSIT_MIN_SHARES = 0.000040000000307199e18;

    address public COLLATERAL_TOKEN_ADDRESS = 0xDBDC1Ef57537E34680B898E1FEBD3D68c7389bCB;
    address public DEBT_TOKEN_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    string public COLLATERAL_TOKEN_NAME = "Staked infiniFi USD";
    string public COLLATERAL_TOKEN_SYMBOL = "siUSD";
    string public DEBT_TOKEN_NAME = "USD Coin";
    string public DEBT_TOKEN_SYMBOL = "USDC";

    function run() public {
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        console.log("Deploying...");

        vm.startBroadcast();

        address deployerAddress = msg.sender;
        console.log("DeployerAddress: ", deployerAddress);

        ILeverageTokenDeploymentBatcher.LeverageTokenDeploymentParams memory leverageTokenDeploymentParams =
            ILeverageTokenDeploymentBatcher.LeverageTokenDeploymentParams({
                leverageTokenName: LT_NAME,
                leverageTokenSymbol: LT_SYMBOL,
                mintTokenFee: MINT_TOKEN_FEE,
                redeemTokenFee: REDEEM_TOKEN_FEE
            });

        ILeverageTokenDeploymentBatcher.MorphoLendingAdapterDeploymentParams memory lendingAdapterDeploymentParams =
            ILeverageTokenDeploymentBatcher.MorphoLendingAdapterDeploymentParams({
                morphoMarketId: MORPHO_MARKET_ID, baseSalt: BASE_SALT
            });

        ILeverageTokenDeploymentBatcher.RebalanceAdapterDeploymentParams memory rebalanceAdapterDeploymentParams =
            ILeverageTokenDeploymentBatcher.RebalanceAdapterDeploymentParams({
                implementation: DeployConstants.DUTCH_AUCTION_PRE_LIQUIDATION_COLLATERAL_RATIOS_REBALANCE_ADAPTER_IMPLEMENTATION,
                owner: DeployConstants.DEPLOYER,
                minCollateralRatio: MIN_COLLATERAL_RATIO,
                targetCollateralRatio: TARGET_COLLATERAL_RATIO,
                maxCollateralRatio: MAX_COLLATERAL_RATIO,
                auctionDuration: AUCTION_DURATION,
                initialPriceMultiplier: INITIAL_PRICE_MULTIPLIER,
                minPriceMultiplier: MIN_PRICE_MULTIPLIER,
                preLiquidationCollateralRatioThreshold: PRE_LIQUIDATION_COLLATERAL_RATIO_THRESHOLD,
                rebalanceReward: REBALANCE_REWARD
            });

        IERC20(COLLATERAL_TOKEN_ADDRESS).approve(address(leverageTokenDeploymentBatcher), INITIAL_COLLATERAL_DEPOSIT);
        (ILeverageToken leverageToken, ActionData memory depositData) = leverageTokenDeploymentBatcher.deployLeverageTokenAndDeposit(
            leverageTokenDeploymentParams,
            lendingAdapterDeploymentParams,
            rebalanceAdapterDeploymentParams,
            INITIAL_COLLATERAL_DEPOSIT,
            INITIAL_COLLATERAL_DEPOSIT_MIN_SHARES
        );

        console.log("LeverageToken deployed at: ", address(leverageToken));

        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)));
        console.log("LendingAdapter deployed at: ", address(lendingAdapter));

        address rebalanceAdapterProxy = address(leverageManager.getLeverageTokenRebalanceAdapter(leverageToken));
        console.log("RebalanceAdapter proxy deployed at: ", rebalanceAdapterProxy);

        require(Id.unwrap(lendingAdapter.morphoMarketId()) == Id.unwrap(MORPHO_MARKET_ID), "Invalid market");

        IMorpho morpho = IMorpho(DeployConstants.MORPHO);
        MarketParams memory marketParams = morpho.idToMarketParams(lendingAdapter.morphoMarketId());
        IERC20Metadata loanToken = IERC20Metadata(marketParams.loanToken);
        IERC20Metadata collateralToken = IERC20Metadata(marketParams.collateralToken);

        require(address(loanToken) == DEBT_TOKEN_ADDRESS, "Incorrect debt token on Morpho market");
        require(address(collateralToken) == COLLATERAL_TOKEN_ADDRESS, "Incorrect collateral token on Morpho market");

        _assertEqString(loanToken.name(), DEBT_TOKEN_NAME);
        _assertEqString(loanToken.symbol(), DEBT_TOKEN_SYMBOL);
        _assertEqString(collateralToken.name(), COLLATERAL_TOKEN_NAME);
        _assertEqString(collateralToken.symbol(), COLLATERAL_TOKEN_SYMBOL);

        uint256 preLiquidationThreshold =
            IPreLiquidationRebalanceAdapter(address(rebalanceAdapterProxy)).getCollateralRatioThreshold();
        uint256 preLiquidationLltv = Math.mulDiv(WAD, WAD, preLiquidationThreshold);
        uint256 marketLltv = marketParams.lltv;

        require(marketLltv >= preLiquidationLltv, "Market LLTV is less than pre-liquidation LLTV");

        uint256 minCollateralRatio =
            ICollateralRatiosRebalanceAdapter(address(rebalanceAdapterProxy)).getLeverageTokenMinCollateralRatio();
        uint256 minLtv = Math.mulDiv(WAD, WAD, minCollateralRatio);
        require(marketLltv >= minLtv, "Market LLTV is less than min LTV");

        require(
            minCollateralRatio >= preLiquidationThreshold,
            "Min collateral ratio is less than pre-liquidation collateral ratio threshold"
        );

        console.log("Performed initial deposit to leverage token");
        console.log("  Collateral: ", depositData.collateral);
        console.log("  Debt: ", depositData.debt);
        console.log("  Shares: ", depositData.shares);
        console.log("  Token fee: ", depositData.tokenFee);
        console.log("  Treasury fee: ", depositData.treasuryFee);

        vm.stopBroadcast();
    }

    function _assertEqString(string memory a, string memory b) internal pure {
        require(keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)), "Invalid token name or symbol");
    }
}
