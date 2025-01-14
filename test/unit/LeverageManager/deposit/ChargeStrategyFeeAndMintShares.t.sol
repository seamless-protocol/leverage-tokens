// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ChargeStrategyFeeAndMintSharesTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_chargeStrategyFeeAndMintShares(uint256 fee, address to, uint256 shares) public {
        fee = bound(fee, 0, leverageManager.MAX_FEE());
        _setStrategyActionFee(feeManagerRole, strategyId, IFeeManager.Action.Deposit, fee);

        uint256 expectedShares =
            leverageManager.exposed_chargeStrategyFee(strategyId, shares, IFeeManager.Action.Deposit);

        uint256 returnValue =
            leverageManager.exposed_chargeStrategyFeeAndMintShares(strategyId, to, shares, expectedShares);

        assertEq(leverageManager.getTotalStrategyShares(strategyId), expectedShares);
        assertEq(leverageManager.getUserStrategyShares(strategyId, to), expectedShares);
        assertEq(returnValue, expectedShares);
    }

    function testFuzz_chargeStrategyFeeAndMintShares_RevertIf_NotEnoughShares(uint256 fee, address to, uint256 shares)
        public
    {
        fee = bound(fee, 1, leverageManager.MAX_FEE());
        _setStrategyActionFee(feeManagerRole, strategyId, IFeeManager.Action.Deposit, fee);

        uint256 expectedShares =
            leverageManager.exposed_chargeStrategyFee(strategyId, shares, IFeeManager.Action.Deposit);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.InsufficientShares.selector, expectedShares, expectedShares + 1)
        );
        leverageManager.exposed_chargeStrategyFeeAndMintShares(strategyId, to, shares, expectedShares + 1);
    }
}
