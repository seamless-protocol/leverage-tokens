// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {RebalanceAction, ActionType} from "src/types/DataTypes.sol";

contract TransferTokensTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_IsElementInSlice() public {
        RebalanceAction[] memory actions = new RebalanceAction[](4);

        actions[0] =
            RebalanceAction({strategy: IStrategy(address(0)), actionType: ActionType.AddCollateral, amount: 100});
        actions[1] =
            RebalanceAction({strategy: IStrategy(address(1)), actionType: ActionType.AddCollateral, amount: 100});
        actions[2] =
            RebalanceAction({strategy: IStrategy(address(2)), actionType: ActionType.AddCollateral, amount: 100});
        actions[3] =
            RebalanceAction({strategy: IStrategy(address(3)), actionType: ActionType.AddCollateral, amount: 100});

        assertEq(leverageManager.exposed_isElementInSlice(actions, IStrategy(address(0)), 1), true);
        assertEq(leverageManager.exposed_isElementInSlice(actions, IStrategy(address(2)), 4), true);
        assertEq(leverageManager.exposed_isElementInSlice(actions, IStrategy(address(0)), 0), false);
        assertEq(leverageManager.exposed_isElementInSlice(actions, IStrategy(address(2)), 2), false);
    }
}
