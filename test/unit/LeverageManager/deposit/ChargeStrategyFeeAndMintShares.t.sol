// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IStrategyToken} from "src/interfaces/IStrategyToken.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract ChargeStrategyFeeAndMintSharesTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        _createDummyStrategy();
    }

    function testFuzz_computeFeeAdjustedSharesAndMintShares(uint256 fee, address to, uint256 shares) public {
        fee = bound(fee, 0, leverageManager.MAX_FEE());
        _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action.Deposit, fee);

        uint256 expectedShares =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, shares, IFeeManager.Action.Deposit);

        uint256 returnValue =
            leverageManager.exposed_computeFeeAdjustedSharesAndMintShares(strategy, to, shares, expectedShares);

        assertEq(IStrategyToken(strategy).totalSupply(), expectedShares);
        assertEq(IStrategyToken(strategy).balanceOf(to), expectedShares);
        assertEq(returnValue, expectedShares);
    }

    function testFuzz_computeFeeAdjustedSharesAndMintShares_RevertIf_NotEnoughShares(
        uint256 fee,
        address to,
        uint256 shares
    ) public {
        fee = bound(fee, 1, leverageManager.MAX_FEE());
        _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action.Deposit, fee);

        uint256 expectedShares =
            leverageManager.exposed_computeFeeAdjustedShares(strategy, shares, IFeeManager.Action.Deposit);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.InsufficientShares.selector, expectedShares, expectedShares + 1)
        );
        leverageManager.exposed_computeFeeAdjustedSharesAndMintShares(strategy, to, shares, expectedShares + 1);
    }
}
