// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ActionData, LeverageTokenState} from "src/types/DataTypes.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";

contract LeverageManagerHandler is Test {
    enum ActionType {
        // Invariants are checked before any calls are made as well, so we need a specific identifer for it for filtering
        Initial,
        Deposit,
        AddCollateral,
        RepayDebt,
        Withdraw,
        UpdateOraclePrice
    }

    struct AddCollateralActionData {
        uint256 collateral;
    }

    struct DepositActionData {
        ILeverageToken leverageToken;
        uint256 equityInCollateralAsset;
        uint256 equityInDebtAsset;
        ActionData preview;
    }

    struct RepayDebtActionData {
        uint256 debt;
    }

    struct WithdrawActionData {
        ILeverageToken leverageToken;
        uint256 equityInCollateralAsset;
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
        uint256 totalSupply;
        bytes actionData;
    }

    uint256 public BASE_RATIO;

    LeverageManagerHarness public leverageManager;
    ILeverageToken[] public leverageTokens;
    address[] public actors;

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
        address[] memory _actors
    ) {
        leverageManager = _leverageManager;
        leverageTokens = _leverageTokens;
        actors = _actors;

        BASE_RATIO = leverageManager.BASE_RATIO();

        vm.label(address(leverageManager), "leverageManager");

        for (uint256 i = 0; i < _leverageTokens.length; i++) {
            vm.label(
                address(_leverageTokens[i]),
                string.concat("leverageToken-", Strings.toHexString(uint256(uint160(address(_leverageTokens[i]))), 20))
            );
        }
    }

    function deposit(uint256 seed) public useLeverageToken useActor {
        uint256 equityForDeposit = _boundEquityForDeposit(currentLeverageToken, seed);

        ActionData memory preview = leverageManager.previewDeposit(currentLeverageToken, equityForDeposit);
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken);

        _saveLeverageTokenState(
            currentLeverageToken,
            ActionType.Deposit,
            abi.encode(
                DepositActionData({
                    leverageToken: currentLeverageToken,
                    equityInCollateralAsset: equityForDeposit,
                    equityInDebtAsset: lendingAdapter.convertCollateralToDebtAsset(equityForDeposit),
                    preview: preview
                })
            )
        );

        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(currentLeverageToken);
        deal(address(collateralAsset), currentActor, type(uint256).max);
        collateralAsset.approve(address(leverageManager), type(uint256).max);
        leverageManager.deposit(currentLeverageToken, equityForDeposit, 0);
    }

    /// @dev Simulates someone adding collateral to the position held by the leverage token directly, not through the LeverageManager.
    function addCollateral(uint256 seed) public useLeverageToken {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken)));
        uint256 collateral = lendingAdapter.getCollateral();
        IERC20 collateralAsset = lendingAdapter.collateralAsset();
        uint256 collateralToAdd = bound(seed, 0, type(uint128).max - collateral);

        _saveLeverageTokenState(
            currentLeverageToken,
            ActionType.AddCollateral,
            abi.encode(AddCollateralActionData({collateral: collateralToAdd}))
        );

        deal(address(collateralAsset), address(this), collateralToAdd);
        collateralAsset.approve(address(lendingAdapter), collateralToAdd);
        lendingAdapter.addCollateral(collateralToAdd);
    }

    /// @dev Simulates someone repaying debt from the position held by the leverage token directly, not through the LeverageManager.
    function repayDebt(uint256 seed) public useLeverageToken {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken)));
        uint256 debt = lendingAdapter.getDebt();
        IERC20 debtAsset = lendingAdapter.debtAsset();
        uint256 debtToRemove = bound(seed, 0, debt);

        _saveLeverageTokenState(
            currentLeverageToken, ActionType.RepayDebt, abi.encode(RepayDebtActionData({debt: debtToRemove}))
        );

        deal(address(debtAsset), address(this), debtToRemove);
        debtAsset.approve(address(lendingAdapter), debtToRemove);
        lendingAdapter.repay(debtToRemove);
    }

    function withdraw(uint256 seed) public useLeverageToken useActor {
        uint256 equityForWithdraw = _boundEquityForWithdraw(currentLeverageToken, currentActor, seed);

        ActionData memory preview = leverageManager.previewWithdraw(currentLeverageToken, equityForWithdraw);

        _saveLeverageTokenState(
            currentLeverageToken,
            ActionType.Withdraw,
            abi.encode(
                WithdrawActionData({
                    leverageToken: currentLeverageToken,
                    equityInCollateralAsset: equityForWithdraw,
                    preview: preview
                })
            )
        );

        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(currentLeverageToken);
        deal(address(debtAsset), currentActor, type(uint256).max);
        debtAsset.approve(address(leverageManager), type(uint256).max);
        leverageManager.withdraw(currentLeverageToken, equityForWithdraw, currentLeverageToken.balanceOf(currentActor));
    }

    /// @dev Simulates updates to the oracle used by the lending adapter of a leverage token
    function updateOraclePrice(uint256 seed) public useLeverageToken {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(currentLeverageToken)));

        uint256 newExchangeRate = bound(seed, 0, type(uint256).max);
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(newExchangeRate);

        _saveLeverageTokenState(currentLeverageToken, ActionType.UpdateOraclePrice, "");
    }

    function convertToAssets(ILeverageToken leverageToken, uint256 shares) public view returns (uint256) {
        return Math.mulDiv(
            shares,
            leverageManager.getLeverageTokenLendingAdapter(leverageToken).getEquityInCollateralAsset() + 1,
            leverageToken.totalSupply() + 1,
            Math.Rounding.Floor
        );
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

    /// @dev Bounds the amount of equity to deposit based on the maximum collateral and debt that can be added to a leverage token
    ///      due to overflow limits
    function _boundEquityForDeposit(ILeverageToken leverageToken, uint256 seed) internal view returns (uint256) {
        LeverageTokenState memory stateBefore = leverageManager.getLeverageTokenState(leverageToken);

        uint256 maxCollateralAmount = type(uint128).max
            - leverageManager.getLeverageTokenLendingAdapter(leverageToken).convertDebtToCollateralAsset(
                stateBefore.collateralInDebtAsset
            );
        // Bound the amount of equity to deposit based on the maximum collateral that can be added
        bool shouldFollowTargetRatio = leverageToken.totalSupply() == 0 || stateBefore.debt == 0;
        uint256 collateralRatioForDeposit = shouldFollowTargetRatio
            ? leverageManager.getLeverageTokenTargetCollateralRatio(leverageToken)
            : stateBefore.collateralRatio;

        // Divide first to avoid overflow
        uint256 maxEquity = (maxCollateralAmount / collateralRatioForDeposit) * (collateralRatioForDeposit - BASE_RATIO);

        // Divide max equity by a random number between 2 and 100000 to split deposits up more among calls
        uint256 equityDivisor = bound(seed, 2, 100000);
        return bound(seed, 0, maxEquity / equityDivisor);
    }

    function _boundEquityForWithdraw(ILeverageToken leverageToken, address actor, uint256 seed)
        internal
        view
        returns (uint256)
    {
        uint256 shares = leverageToken.balanceOf(actor);
        uint256 maxEquity = convertToAssets(leverageToken, shares);

        // Divide max equity by a random number between 1 and 10 to split withdrawals up more among calls
        uint256 equityDivisor = bound(seed, 1, 10);
        return bound(seed, 0, maxEquity / equityDivisor);
    }

    function _saveLeverageTokenState(ILeverageToken leverageToken, ActionType actionType, bytes memory actionData)
        internal
    {
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(leverageToken);

        uint256 collateralRatio = leverageManager.getLeverageTokenState(leverageToken).collateralRatio;
        uint256 collateral = lendingAdapter.getCollateral();
        uint256 collateralInDebtAsset = lendingAdapter.convertCollateralToDebtAsset(collateral);
        uint256 debt = lendingAdapter.getDebt();
        uint256 totalSupply = leverageToken.totalSupply();
        uint256 equityInCollateralAsset = lendingAdapter.getEquityInCollateralAsset();
        uint256 equityInDebtAsset = lendingAdapter.getEquityInDebtAsset();

        leverageTokenStateBefore = LeverageTokenStateData({
            leverageToken: leverageToken,
            actionType: actionType,
            collateral: collateral,
            collateralInDebtAsset: collateralInDebtAsset,
            debt: debt,
            equityInCollateralAsset: equityInCollateralAsset,
            equityInDebtAsset: equityInDebtAsset,
            collateralRatio: collateralRatio,
            totalSupply: totalSupply,
            actionData: actionData
        });
    }
}
