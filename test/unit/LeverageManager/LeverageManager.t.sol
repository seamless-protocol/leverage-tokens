// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerHarness} from "test/unit/harness/LeverageManagerHarness.t.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";
import {FeeManagerHarness} from "test/unit/harness/FeeManagerHarness.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {ExternalAction, LeverageTokenConfig} from "src/types/DataTypes.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";

contract LeverageManagerTest is FeeManagerTest {
    ILeverageToken public leverageToken;
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");
    address public treasury = makeAddr("treasury");

    MockERC20 public collateralToken = new MockERC20();
    MockERC20 public debtToken = new MockERC20();

    MockLendingAdapter public lendingAdapter;

    address public leverageTokenImplementation;
    BeaconProxyFactory public leverageTokenFactory;
    LeverageManagerHarness public leverageManager;

    function setUp() public virtual override {
        leverageTokenImplementation = address(new LeverageToken());
        leverageTokenFactory = new BeaconProxyFactory(leverageTokenImplementation, address(this));
        lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));

        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
        );
        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        vm.startPrank(defaultAdmin);
        leverageManager.setLeverageTokenFactory(address(leverageTokenFactory));

        leverageManager.grantRole(leverageManager.MANAGER_ROLE(), manager);
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), feeManagerRole);

        feeManager = FeeManagerHarness(address(leverageManager));
        vm.stopPrank();

        _setTreasury(feeManagerRole, treasury);
    }

    function test_setUp() public view virtual override {
        bytes32 expectedSlot = keccak256(
            abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)
        ) & ~bytes32(uint256(0xff));

        assertTrue(leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), defaultAdmin));
        assertEq(leverageManager.exposed_getLeverageManagerStorageSlot(), expectedSlot);
    }

    function _BASE_RATIO() internal view returns (uint256) {
        return leverageManager.BASE_RATIO();
    }

    function _MAX_FEE() internal view returns (uint256) {
        return IFeeManager(address(leverageManager)).MAX_FEE();
    }

    function _DECIMALS_OFFSET() internal view returns (uint256) {
        return leverageManager.DECIMALS_OFFSET();
    }

    function _getLendingAdapter() internal view returns (ILendingAdapter) {
        return leverageManager.getLeverageTokenLendingAdapter(leverageToken);
    }

    function _createDummyLeverageToken() internal {
        leverageToken = ILeverageToken(
            _createNewLeverageToken(
                manager,
                LeverageTokenConfig({
                    lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                    targetCollateralRatio: _BASE_RATIO() + 1,
                    rebalanceModule: IRebalanceAdapter(address(0)),
                    depositTokenFee: 0,
                    withdrawTokenFee: 0
                }),
                address(0),
                address(0),
                "dummy name",
                "dummy symbol"
            )
        );
    }

    function _createNewLeverageToken(
        address caller,
        LeverageTokenConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) internal returns (ILeverageToken) {
        vm.mockCall(
            address(config.lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getCollateralAsset.selector),
            abi.encode(IERC20(collateralAsset))
        );
        vm.mockCall(
            address(config.lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getDebtAsset.selector),
            abi.encode(IERC20(debtAsset))
        );

        vm.startPrank(caller);
        leverageToken = leverageManager.createNewLeverageToken(config, name, symbol, "");
        vm.stopPrank();

        return leverageToken;
    }

    function _mintShares(address recipient, uint256 amount) internal {
        vm.prank(address(leverageManager));
        leverageToken.mint(recipient, amount);
    }

    struct ConvertToSharesState {
        uint256 totalEquity;
        uint256 sharesTotalSupply;
    }

    function _mockState_ConvertToShares(ConvertToSharesState memory state) internal {
        _mintShares(address(1), state.sharesTotalSupply);
        _mockLeverageTokenTotalEquityInCollateralAsset(state.totalEquity);
    }

    function _mockLeverageTokenTotalEquityInCollateralAsset(uint256 equity) internal {
        vm.mockCall(
            address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)),
            abi.encodeWithSelector(ILendingAdapter.getEquityInCollateralAsset.selector),
            abi.encode(equity)
        );
    }

    function _setTreasuryActionFee(ExternalAction action, uint256 fee) internal {
        vm.prank(feeManagerRole);
        leverageManager.setTreasuryActionFee(action, fee);
    }

    function _mockLeverageTokenDebt(uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)),
            abi.encodeWithSelector(ILendingAdapter.getDebt.selector),
            abi.encode(debt)
        );
    }

    function _mockLeverageTokenCollateralInDebtAsset(uint256 collateral) internal {
        vm.mockCall(
            address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)),
            abi.encodeWithSelector(ILendingAdapter.getCollateralInDebtAsset.selector),
            abi.encode(collateral)
        );
    }
}
