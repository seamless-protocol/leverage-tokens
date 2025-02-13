// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract GetStrategyStateTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: _BASE_RATIO() + 1,
                maxCollateralRatio: 3 * _BASE_RATIO(),
                targetCollateralRatio: 2 * _BASE_RATIO(), // 2x leverage
                collateralCap: type(uint256).max
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    function test_getStrategyState() public {
        lendingAdapter.mockDebt(50 ether);
        lendingAdapter.mockCollateral(200 ether);

        // 2:1 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(0.5e8);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateral, 200 ether);
        assertEq(state.debt, 50 ether);
        assertEq(state.collateralRatio, 2 * _BASE_RATIO());
    }

    function test_getStrategyState_ZeroDebt() public {
        lendingAdapter.mockDebt(0);
        lendingAdapter.mockCollateral(200 ether);

        // 2:1 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(0.5e8);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);

        assertEq(state.collateral, 200 ether);
        assertEq(state.debt, 0);
        assertEq(state.collateralRatio, type(uint256).max);
    }
}
