// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/wrappers/FeeManagerHarness.sol";
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ChargeStrategyFeeAndMintSharesTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_chargeStrategyFeeAndMintShares(address strategy, uint256 fee, address to, uint256 shares)
        public
    {
        fee = bound(fee, 0, leverageManager.MAX_FEE());
        _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action.Deposit, fee);

        uint256 expectedShares =
            FeeManagerHarness(address(leverageManager)).chargeStrategyFee(strategy, shares, IFeeManager.Action.Deposit);

        uint256 returnValue = leverageManager.chargeStrategyFeeAndMintShares(strategy, to, shares, expectedShares);

        assertEq(leverageManager.getTotalStrategyShares(strategy), expectedShares);
        assertEq(leverageManager.getUserStrategyShares(strategy, to), expectedShares);
        assertEq(returnValue, expectedShares);
    }

    function testFuzz_chargeStrategyFeeAndMintShares_RevertIf_NotEnoughShares(
        address strategy,
        uint256 fee,
        address to,
        uint256 shares
    ) public {
        fee = bound(fee, 1, leverageManager.MAX_FEE());
        _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action.Deposit, fee);

        uint256 expectedShares =
            FeeManagerHarness(address(leverageManager)).chargeStrategyFee(strategy, shares, IFeeManager.Action.Deposit);

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.InsufficientShares.selector));
        leverageManager.chargeStrategyFeeAndMintShares(strategy, to, shares, expectedShares + 1);
    }
}
