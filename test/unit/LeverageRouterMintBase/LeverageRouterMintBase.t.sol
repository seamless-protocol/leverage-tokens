// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Id, MarketParams, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageRouterMintBase} from "src/periphery/LeverageRouterMintBase.sol";
import {LeverageRouterMintBaseHarness} from "../harness/LeverageRouterMintBaseHarness.t.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockLendingAdapter} from "../mock/MockLendingAdapter.sol";
import {MockLeverageManager} from "../mock/MockLeverageManager.sol";
import {MockMorpho} from "../mock/MockMorpho.sol";

contract LeverageRouterMintBaseTest is Test {
    MockERC20 public collateralToken = new MockERC20();
    MockERC20 public debtToken = new MockERC20();
    ILeverageToken public leverageToken = ILeverageToken(address(new MockERC20()));

    MockMorpho public morpho;

    // Mocked Morpho protocol is setup with a market with some default market params
    Id public defaultMarketId;
    MarketParams public defaultMarketParams = MarketParams({
        loanToken: address(debtToken),
        collateralToken: address(collateralToken),
        oracle: makeAddr("mockMorphoMarketOracle"), // doesn't matter for these tests as calls to morpho should be mocked
        irm: makeAddr("mockMorphoIRM"), // doesn't matter for these tests as calls to morpho should be mocked
        lltv: 1e18 // 100%, doesn't matter for these tests as calls to morpho should be mocked
    });

    MockLendingAdapter public lendingAdapter;

    MockLeverageManager public leverageManager;

    LeverageRouterMintBaseHarness public leverageRouterMintBase;

    function setUp() public virtual {
        // Setup mocked contracts
        defaultMarketId = MarketParamsLib.id(defaultMarketParams);
        morpho = new MockMorpho(defaultMarketId, defaultMarketParams);
        lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken), address(this));
        leverageManager = new MockLeverageManager();
        leverageManager.setLeverageTokenData(
            leverageToken,
            MockLeverageManager.LeverageTokenData({
                leverageToken: leverageToken,
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                collateralAsset: collateralToken,
                debtAsset: debtToken
            })
        );

        leverageRouterMintBase = new LeverageRouterMintBaseHarness(
            ILeverageManager(address(leverageManager)), IMorpho(address(morpho)), collateralToken
        );

        vm.label(address(collateralToken), "CollateralToken");
        vm.label(address(debtToken), "DebtToken");
        vm.label(address(leverageToken), "LeverageTokenToken");
    }

    function test_setUp() public view {
        assertEq(address(leverageRouterMintBase.leverageManager()), address(leverageManager));
        assertEq(address(leverageRouterMintBase.morpho()), address(morpho));
    }

    function _mockLeverageManagerMint(
        uint256 requiredCollateral,
        uint256 equityInCollateralAsset,
        uint256 requiredDebt,
        uint256 shares
    ) internal {
        // Mock the mint preview
        leverageManager.setMockPreviewMintData(
            MockLeverageManager.PreviewParams({
                leverageToken: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset
            }),
            MockLeverageManager.MockPreviewMintData({
                collateralToAdd: requiredCollateral,
                debtToBorrow: requiredDebt,
                shares: shares,
                tokenFee: 0,
                treasuryFee: 0
            })
        );

        // Mock the LeverageManager mint
        leverageManager.setMockMintData(
            MockLeverageManager.MintParams({
                leverageToken: leverageToken,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: shares
            }),
            MockLeverageManager.MockMintData({
                collateral: requiredCollateral,
                debt: requiredDebt,
                shares: shares,
                isExecuted: false
            })
        );
    }
}
