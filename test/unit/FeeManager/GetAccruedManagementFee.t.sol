// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract GetAccruedManagementFeeTest is FeeManagerTest {
    function test_getAccruedManagementFee() public {
        vm.prank(feeManagerRole);
        feeManager.setManagementFee(0.1e4);

        uint256 totalSupply = 1000;
        leverageToken.mint(address(this), totalSupply);

        vm.warp(0);
        feeManager.chargeManagementFee(leverageToken);
        skip(SECONDS_ONE_YEAR / 2);

        uint256 sharesFee = feeManager.exposed_getAccruedManagementFee(leverageToken);

        assertEq(sharesFee, 50); // half of 10% of 1000 total supply

        feeManager.chargeManagementFee(leverageToken);
        skip(SECONDS_ONE_YEAR / 2);

        sharesFee = feeManager.exposed_getAccruedManagementFee(leverageToken);
        assertEq(sharesFee, 53); // half of 10% of 1000 + 50, rounded up
    }

    function testFuzz_getAccruedManagementFee_RoundsUp(uint128 totalSupply, uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 1, MAX_FEE));

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        leverageToken.mint(address(this), totalSupply);

        vm.warp(0);
        feeManager.chargeManagementFee(leverageToken);
        skip(SECONDS_ONE_YEAR);

        uint256 sharesFee = feeManager.exposed_getAccruedManagementFee(leverageToken);

        assertEq(sharesFee, Math.mulDiv(totalSupply, managementFee, MAX_FEE, Math.Rounding.Ceil));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_getAccruedManagementFee_ZeroDuration(uint128 totalSupply, uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 1, MAX_FEE));

        leverageToken.mint(address(this), totalSupply);

        vm.warp(0);
        feeManager.chargeManagementFee(leverageToken);

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        uint256 shares = feeManager.exposed_getAccruedManagementFee(leverageToken);

        assertEq(shares, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_getAccruedManagementFee_ZeroManagementFee(uint256 totalSupply, uint120 deltaT) public {
        vm.prank(feeManagerRole);
        feeManager.setManagementFee(0);

        leverageToken.mint(address(this), totalSupply);

        feeManager.chargeManagementFee(leverageToken);
        skip(deltaT);

        uint256 shares = feeManager.exposed_getAccruedManagementFee(leverageToken);
        assertEq(shares, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_getAccruedManagementFee_ZeroTotalSupply(uint128 managementFee, uint120 deltaT) public {
        managementFee = uint128(bound(managementFee, 1, MAX_FEE));
        deltaT = uint120(bound(deltaT, 1, type(uint120).max));

        feeManager.chargeManagementFee(leverageToken);
        skip(deltaT);

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        uint256 shares = feeManager.exposed_getAccruedManagementFee(leverageToken);

        assertEq(shares, 0);
    }
}
