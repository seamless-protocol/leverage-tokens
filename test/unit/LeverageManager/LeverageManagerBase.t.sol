// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependencies imports
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerWrapper} from "test/unit/LeverageManager/wrappers/LeverageManagerWrapper.sol";

contract LeverageManagerBaseTest is Test {
    address public lendingContract = makeAddr("lendingContract");
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");

    uint256 public BASE_RATIO;
    LeverageManagerWrapper public leverageManager;

    function setUp() public virtual {
        address leverageManagerImplementation = address(new LeverageManagerWrapper());
        address leverageManagerProxy = address(
            new ERC1967Proxy(
                leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
            )
        );

        leverageManager = LeverageManagerWrapper(leverageManagerProxy);
        BASE_RATIO = leverageManager.BASE_RATIO();

        vm.startPrank(defaultAdmin);
        leverageManager.grantRole(leverageManager.MANAGER_ROLE(), manager);
        vm.stopPrank();

        // TODO: Update this when external contract is figured out
        vm.startPrank(manager);
        leverageManager.setLendingContract(lendingContract);
        vm.stopPrank();
    }

    function test_setUp() public view {
        assertTrue(leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), defaultAdmin));
    }

    struct CalculateDebtAndSharesState {
        address strategy;
        uint256 targetRatio;
        uint128 collateral;
        uint128 convertedCollateral;
        uint128 totalEquity;
        uint128 strategyTotalShares;
    }

    function _mockState_CalculateDebtAndShares(CalculateDebtAndSharesState memory state) internal {
        _mockStrategyTotalSupply(state.strategy, state.strategyTotalShares);
        _mockStrategyTotalEquity(state.strategy, state.totalEquity);
        _mockConvertCollateral(state.strategy, state.collateral, state.convertedCollateral);
        _mockStrategyTargetRatio(state.strategy, state.targetRatio);
    }

    function _mockConvertCollateral(address strategy, uint256 collateral, uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getLendingContract()),
            abi.encodeWithSelector(ILendingContract.convertCollateralToDebtAsset.selector, strategy, collateral),
            abi.encode(debt)
        );
    }

    function _mockStrategyTotalEquity(address strategy, uint256 totalEquity) internal {
        vm.mockCall(
            address(leverageManager.getLendingContract()),
            abi.encodeWithSelector(ILendingContract.getStrategyEquityInDebtAsset.selector, strategy),
            abi.encode(totalEquity)
        );
    }

    function _mockStrategyTotalSupply(address strategy, uint256 totalSupply) internal {
        leverageManager.mintShares(strategy, address(0), totalSupply);
    }

    function _mockStrategyTargetRatio(address strategy, uint256 targetRatio) internal {
        vm.prank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            Storage.CollateralRatios({minForRebalance: 0, target: targetRatio, maxForRebalance: type(uint256).max})
        );
    }
}
