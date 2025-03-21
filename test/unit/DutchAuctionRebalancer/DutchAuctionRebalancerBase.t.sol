// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {MockRebalanceModule} from "../mock/MockRebalanceModule.sol";
import {DutchAuctionRebalancer} from "src/DutchAuctionRebalancer.sol";
import {DutchAuctionRebalancerHarness} from "./harness/DutchAuctionRebalancerHarness.t.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockLendingAdapter} from "../mock/MockLendingAdapter.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract DutchAuctionRebalancerBaseTest is Test {
    // Common constants used across tests
    uint256 public constant BPS_DENOMINATOR = 1e18;
    uint256 public constant BASE_RATIO = 1e8; // 1.0 with 8 decimals precision
    uint256 public constant MIN_RATIO = 1e8; // 1x
    uint256 public constant MAX_RATIO = 3e8; // 3x
    uint256 public constant TARGET_RATIO = 2e8; // 2x
    uint256 public constant AUCTION_START_TIME = 1000;
    uint256 public constant DEFAULT_DURATION = 1 days;
    uint256 public constant DEFAULT_INITIAL_PRICE_MULTIPLIER = 1.1 * 1e18;
    uint256 public constant DEFAULT_MIN_PRICE_MULTIPLIER = 0.1 * 1e18;

    MockERC20 public collateralToken;
    MockERC20 public debtToken;
    IStrategy public strategy;

    MockLendingAdapter public lendingAdapter;
    MockLeverageManager public leverageManager;
    DutchAuctionRebalancerHarness public auctionRebalancer;
    MockRebalanceModule public rebalanceModule;

    address public owner = makeAddr("owner");

    function setUp() public virtual {
        // Setup mock tokens
        collateralToken = new MockERC20();
        debtToken = new MockERC20();
        strategy = IStrategy(address(new MockERC20()));

        // Setup mock adapters and managers
        lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));
        leverageManager = new MockLeverageManager();
        rebalanceModule = new MockRebalanceModule();

        // Setup strategy data in leverage manager
        leverageManager.setStrategyData(
            strategy,
            MockLeverageManager.StrategyData({
                strategyToken: strategy,
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                collateralAsset: collateralToken,
                debtAsset: debtToken,
                targetCollateralRatio: TARGET_RATIO
            })
        );
        leverageManager.setStrategyRebalanceModule(strategy, address(rebalanceModule));

        // Setup owner and deploy auction rebalancer harness
        auctionRebalancer = new DutchAuctionRebalancerHarness(owner, ILeverageManager(address(leverageManager)));

        // Set default collateral ratios
        _mockStrategyCollateralRatios(MIN_RATIO, MAX_RATIO);

        // Set default auction parameters
        _setAuctionParameters(DEFAULT_INITIAL_PRICE_MULTIPLIER, DEFAULT_MIN_PRICE_MULTIPLIER);
    }

    function test_setUp() public {
        assertEq(address(auctionRebalancer.leverageManager()), address(leverageManager));
        assertEq(auctionRebalancer.owner(), owner);
    }

    function _setAuctionParameters(uint256 initialPriceMultiplier, uint256 minPriceMultiplier) internal {
        vm.startPrank(owner);
        auctionRebalancer.setAuctionDuration(strategy, DEFAULT_DURATION);
        auctionRebalancer.setInitialPriceMultiplier(strategy, initialPriceMultiplier);
        auctionRebalancer.setMinPriceMultiplier(strategy, minPriceMultiplier);
        vm.stopPrank();
    }

    function _mockStrategyCollateralRatios(uint256 minRatio, uint256 maxRatio) internal {
        rebalanceModule.mockSetStrategyMinCollateralRatio(strategy, minRatio);
        rebalanceModule.mockSetStrategyMaxCollateralRatio(strategy, maxRatio);
    }

    function _mockIsEligibleForRebalance(bool isEligible) internal {
        rebalanceModule.mockIsEligibleForRebalance(strategy, isEligible);
    }

    function _setStrategyCollateralRatio(uint256 collateralRatio) internal {
        // Note: collateralInDebtAsset, debt and equity are not used in isAuctionValid checks
        StrategyState memory state =
            StrategyState({collateralInDebtAsset: 0, debt: 0, collateralRatio: collateralRatio, equity: 0});
        leverageManager.setStrategyState(strategy, state);
    }

    function _createAuction() internal {
        vm.warp(AUCTION_START_TIME);
        vm.prank(owner);
        auctionRebalancer.createAuction(strategy);
    }
}
