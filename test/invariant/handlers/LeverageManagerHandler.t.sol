// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {ActionData, ExternalAction, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {MockMorphoOracle} from "test/unit/mock/MockMorphoOracle.sol";

contract LeverageManagerHandler is Test {
    enum ActionType {
        // Invariants are checked before any calls are made as well, so we need a specific identifer for it for filtering
        Initial,
        Mint,
        AddCollateral,
        RepayDebt,
        Redeem,
        UpdateOraclePrice
    }

    struct AddCollateralActionData {
        uint256 collateral;
    }

    struct MintActionData {
        ILeverageToken leverageToken;
        uint256 shares;
        ActionData preview;
    }

    struct RepayDebtActionData {
        uint256 debt;
    }

    struct RedeemActionData {
        ILeverageToken leverageToken;
        uint256 shares;
        ActionData preview;
    }

    struct LeverageTokenStateData {
        ILeverageToken leverageToken;
        ActionType actionType;
        uint256 collateral;
        uint256 collateralInDebtAsset;
        uint256 debt;
        uint256 equityInCollateralAsset;
        uint256 equityInDebtAsset;
        uint256 collateralRatio;
        uint256 collateralRatioUsingDebtNormalized;
        uint256 totalSupply;
        bytes actionData;
    }

    uint256 public BASE_RATIO;

    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_ACTION_FEE = WAD - 1;

    LeverageManagerHarness public leverageManager;
    ILeverageToken[] public leverageTokens;
    address[] public actors;
    address public feeManagerRole;

    address public currentActor;
    ILeverageToken public currentLeverageToken;

    LeverageTokenStateData public leverageTokenStateBefore;

    modifier useActor() {
        currentActor = pickActor();
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier useLeverageToken() {
        currentLeverageToken = pickLeverageToken();
        _;
    }

    constructor(
        LeverageManagerHarness _leverageManager,
        ILeverageToken[] memory _leverageTokens,
        address[] memory _actors,
        address _feeManagerRole
    ) {
        leverageManager = _leverageManager;
        leverageTokens = _leverageTokens;
        actors = _actors;
        feeManagerRole = _feeManagerRole;

        BASE_RATIO = leverageManager.BASE_RATIO();

        vm.label(address(leverageManager), "leverageManager");

        for (uint256 i = 0; i < _leverageTokens.length; i++) {
            vm.label(
                address(_leverageTokens[i]),
                string.concat("leverageToken-", Strings.toHexString(uint256(uint160(address(_leverageTokens[i]))), 20))
            );
        }
    }

    function mint(uint256 seed) public useLeverageToken useActor {
        uint256 sharesToMint = _boundSharesForMint(currentLeverageToken, seed);

        ActionData memory preview = leverageManager.previewMint(currentLeverageToken, sharesToMint);

        _saveLeverageTokenState(
            currentLeverageToken,
            ActionType.Mint,
            abi.encode(MintActionData({leverageToken: currentLeverageToken, shares: sharesToMint, preview: preview}))
        );

        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(currentLeverageToken);
        deal(address(collateralAsset), currentActor, preview.collateral);
        collateralAsset.approve(address(leverageManager), preview.collateral);

        leverageManager.mint(currentLeverageToken, sharesToMint, preview.collateral);
    }

    /// @dev Simulates someone adding collateral to the position held by the leverage token directly, not through the LeverageManager.
    function addCollateral(uint256 seed) public useLeverageToken {
        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken)));

        uint256 totalCollateral = lendingAdapter.getCollateral();
        (, address collateralAsset,,,) = lendingAdapter.marketParams();

        uint256 collateralToAdd = bound(seed, 0, type(uint128).max - totalCollateral);

        _saveLeverageTokenState(
            currentLeverageToken,
            ActionType.AddCollateral,
            abi.encode(AddCollateralActionData({collateral: collateralToAdd}))
        );

        deal(address(collateralAsset), address(this), collateralToAdd);
        deal(address(collateralAsset), address(this), collateralToAdd);
        IERC20(collateralAsset).approve(address(lendingAdapter), collateralToAdd);
        lendingAdapter.addCollateral(collateralToAdd);
    }

    /// @dev Simulates someone repaying debt from the position held by the leverage token directly, not through the LeverageManager.
    function repayDebt(uint256 seed) public useLeverageToken {
        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken)));

        uint256 debt = lendingAdapter.getDebt();
        (address debtAsset,,,,) = lendingAdapter.marketParams();

        uint256 debtToRemove = bound(seed, 0, debt);

        _saveLeverageTokenState(
            currentLeverageToken, ActionType.RepayDebt, abi.encode(RepayDebtActionData({debt: debtToRemove}))
        );

        deal(address(debtAsset), address(this), debtToRemove);
        IERC20(debtAsset).approve(address(lendingAdapter), debtToRemove);
        lendingAdapter.repay(debtToRemove);
    }

    function redeem(uint256 seed) public useLeverageToken useActor {
        uint256 sharesForRedeem = _boundSharesForRedeem(currentLeverageToken, currentActor, seed);

        ActionData memory preview = leverageManager.previewRedeem(currentLeverageToken, sharesForRedeem);

        _saveLeverageTokenState(
            currentLeverageToken,
            ActionType.Redeem,
            abi.encode(
                RedeemActionData({leverageToken: currentLeverageToken, shares: sharesForRedeem, preview: preview})
            )
        );

        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(currentLeverageToken);
        deal(address(debtAsset), currentActor, preview.debt);
        debtAsset.approve(address(leverageManager), preview.debt);
        leverageManager.redeem(currentLeverageToken, sharesForRedeem, preview.collateral);
    }

    function setTokenActionFee(uint256 seed) public useLeverageToken {
        uint256 fee = bound(seed, 0, MAX_ACTION_FEE);
        ExternalAction action = ExternalAction(bound(seed, 0, uint256(type(ExternalAction).max)));

        leverageManager.exposed_setLeverageTokenActionFee(currentLeverageToken, action, fee);
    }

    function setTreasuryActionFee(uint256 seed) public useLeverageToken {
        uint256 fee = bound(seed, 0, MAX_ACTION_FEE);
        ExternalAction action = ExternalAction(bound(seed, 0, uint256(type(ExternalAction).max)));

        vm.prank(feeManagerRole);
        leverageManager.setTreasuryActionFee(action, fee);
    }

    /// @dev Simulates updates to the oracle used by the lending adapter of a leverage token
    function updateOraclePrice(uint256 seed) public useLeverageToken {
        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken)));

        (,, address oracle,,) = lendingAdapter.marketParams();

        uint256 newPrice = bound(seed, 0, type(uint256).max);
        MockMorphoOracle(oracle).setPrice(newPrice);

        _saveLeverageTokenState(currentLeverageToken, ActionType.UpdateOraclePrice, "");
    }

    function convertToAssets(ILeverageToken leverageToken, uint256 shares) public view returns (uint256) {
        uint256 equityInCollateralAsset =
            leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInCollateralAsset();

        if (leverageToken.totalSupply() == 0 && equityInCollateralAsset == 0) {
            return shares;
        }

        return Math.mulDiv(shares, equityInCollateralAsset, leverageToken.totalSupply(), Math.Rounding.Floor);
    }

    function getLeverageTokenStateBefore() public view returns (LeverageTokenStateData memory) {
        return leverageTokenStateBefore;
    }

    function pickActor() public returns (address) {
        return actors[bound(vm.randomUint(), 0, actors.length - 1)];
    }

    function pickLeverageToken() public returns (ILeverageToken) {
        return leverageTokens[bound(vm.randomUint(), 0, leverageTokens.length - 1)];
    }

    /// @dev Bounds the amount of shares to mint based on the maximum collateral that can be added to a leverage token
    ///      due to overflow limits
    function _boundSharesForMint(ILeverageToken leverageToken, uint256 seed) internal view returns (uint256) {
        uint256 totalCollateral = leverageManager.getLeverageTokenLendingAdapter(leverageToken).getCollateral();
        uint256 totalDebt = leverageManager.getLeverageTokenLendingAdapter(leverageToken).getDebt();

        // Bound the amount of equity to deposit based on the maximum collateral that can be added to avoid overflow
        bool shouldFollowInitialRatio = leverageToken.totalSupply() == 0;

        // To calculate the amount of collateral required for a given number of shares to mint, the LeverageManager
        // calculates shares * totalCollateral / totalSupply. We need to make sure that this calculate does not overflow.
        // Calculate the maximum shares that can be minted without causing overflow in shares * totalCollateral
        uint256 maxShares;
        if (shouldFollowInitialRatio) {
            uint256 leverageTokenDecimals = IERC20Metadata(address(leverageToken)).decimals();
            uint256 collateralDecimals = IERC20Metadata(
                address(leverageManager.getLeverageTokenLendingAdapter(leverageToken).getCollateralAsset())
            ).decimals();
            uint256 initialCollateralRatio = leverageManager.getLeverageTokenInitialCollateralRatio(leverageToken);

            if (collateralDecimals > leverageTokenDecimals) {
                uint256 scalingFactor = 10 ** (collateralDecimals - leverageTokenDecimals);
                // Prevent overflow in: shares * scalingFactor * initialCollateralRatio, in LeverageManager.convertSharesToCollateral
                maxShares = type(uint128).max / (scalingFactor * initialCollateralRatio);
            } else {
                // In this case, shares is multiplied directly by initialCollateralRatio, in LeverageManager.convertSharesToCollateral
                maxShares = type(uint128).max / initialCollateralRatio;
            }

            uint256 collateralForMaxShares = leverageManager.previewMint(leverageToken, maxShares).collateral;
            uint256 allowedCollateral = type(uint128).max - totalCollateral;

            // Morpho uses uint128 for collateral, the max shares should be scaled down
            // so that the collateral added does not result in overflows.
            // There can be collateral without shares already if someone adds collateral directly on the LendingAdapter when total supply is 0.
            if (collateralForMaxShares > allowedCollateral) {
                if (collateralForMaxShares > allowedCollateral) {
                    maxShares = Math.mulDiv(maxShares, allowedCollateral, collateralForMaxShares, Math.Rounding.Floor);
                }
            }
        } else {
            if (totalDebt == 0) {
                maxShares = type(uint128).max / totalCollateral;
            } else {
                // Debt for the mint is calculated as collateral * totalDebt / totalCollateral.
                // We need to make sure that this calculation does not overflow.
                uint256 maxCollateral = type(uint128).max / totalDebt;

                // Collateral for the mint is calculated as shares * totalCollateral / totalSupply.
                // We need to make sure that this calculation does not overflow.
                maxShares = maxCollateral / totalCollateral;
            }
        }

        // Divide max shares by a random number between 2 and 100000 to split mints up more among calls
        uint256 sharesDivisor = bound(seed, 2, 100000);
        return bound(seed, 0, maxShares / sharesDivisor);
    }

    function _boundSharesForRedeem(ILeverageToken leverageToken, address actor, uint256 seed)
        internal
        view
        returns (uint256)
    {
        uint256 shares = leverageToken.balanceOf(actor);

        // Divide max shares by a random number between 1 and 10 to split redemptions up more among calls
        uint256 sharesDivisor = bound(seed, 1, 10);
        return bound(seed, 0, shares / sharesDivisor);
    }

    function _saveLeverageTokenState(ILeverageToken leverageToken, ActionType actionType, bytes memory actionData)
        internal
    {
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(leverageToken);

        uint256 collateralRatio = leverageManager.getLeverageTokenState(leverageToken).collateralRatio;
        uint256 collateral = lendingAdapter.getCollateral();
        uint256 collateralInDebtAsset = lendingAdapter.convertCollateralToDebtAsset(collateral);
        uint256 debt = lendingAdapter.getDebt();
        uint256 debtInCollateralAsset = lendingAdapter.convertDebtToCollateralAsset(debt);
        uint256 totalSupply = leverageToken.totalSupply();
        uint256 equityInCollateralAsset = lendingAdapter.getEquityInCollateralAsset();
        uint256 equityInDebtAsset = lendingAdapter.getEquityInDebtAsset();
        uint256 collateralRatioUsingDebtNormalized = debtInCollateralAsset > 0
            ? Math.mulDiv(collateral, BASE_RATIO, debtInCollateralAsset, Math.Rounding.Floor)
            : type(uint256).max;

        leverageTokenStateBefore = LeverageTokenStateData({
            leverageToken: leverageToken,
            actionType: actionType,
            collateral: collateral,
            collateralInDebtAsset: collateralInDebtAsset,
            debt: debt,
            equityInCollateralAsset: equityInCollateralAsset,
            equityInDebtAsset: equityInDebtAsset,
            collateralRatio: collateralRatio,
            collateralRatioUsingDebtNormalized: collateralRatioUsingDebtNormalized,
            totalSupply: totalSupply,
            actionData: actionData
        });
    }
}
