// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";

contract GetManagementFeeSharesTest is FeeManagerTest {
    function test_getManagementFeeShares() public {
        vm.prank(feeManagerRole);
        feeManager.setManagementFee(0.1e4);

        uint256 totalSupply = 1000;
        leverageToken.mint(address(this), totalSupply);

        feeManager.exposed_setLastManagementFeeAccrualTimestamp(leverageToken);
        skip(SECONDS_ONE_YEAR / 2);

        uint256 sharesFee = feeManager.exposed_getManagementFeeShares(leverageToken);

        assertEq(sharesFee, 50); // half of 10% of 1000 total supply

        feeManager.exposed_setLastManagementFeeAccrualTimestamp(leverageToken);
        skip(SECONDS_ONE_YEAR / 2);

        sharesFee = feeManager.exposed_getManagementFeeShares(leverageToken);
        assertEq(sharesFee, 50); // other half of 10% of 1000 total supply
    }

    function testFuzz_getManagementFeeShares_RoundsUp(uint128 totalSupply, uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 1, feeManager.MAX_FEE()));

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        leverageToken.mint(address(this), totalSupply);

        feeManager.exposed_setLastManagementFeeAccrualTimestamp(leverageToken);
        skip(SECONDS_ONE_YEAR);

        uint256 sharesFee = feeManager.exposed_getManagementFeeShares(leverageToken);

        assertEq(sharesFee, Math.mulDiv(totalSupply, managementFee, feeManager.MAX_FEE(), Math.Rounding.Ceil));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_getManagementFeeShares_ZeroDuration(uint256 totalSupply, uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 1, feeManager.MAX_FEE()));

        leverageToken.mint(address(this), totalSupply);

        feeManager.exposed_setLastManagementFeeAccrualTimestamp(leverageToken);

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        uint256 shares = feeManager.exposed_getManagementFeeShares(leverageToken);

        assertEq(shares, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_getManagementFeeShares_ZeroManagementFee(uint256 totalSupply, uint120 deltaT) public {
        vm.prank(feeManagerRole);
        feeManager.setManagementFee(0);

        leverageToken.mint(address(this), totalSupply);

        feeManager.exposed_setLastManagementFeeAccrualTimestamp(leverageToken);
        skip(deltaT);

        uint256 shares = feeManager.exposed_getManagementFeeShares(leverageToken);
        assertEq(shares, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_getManagementFeeShares_ZeroTotalSupply(uint128 managementFee, uint120 deltaT) public {
        managementFee = uint128(bound(managementFee, 1, feeManager.MAX_FEE()));
        deltaT = uint120(bound(deltaT, 1, type(uint120).max));

        feeManager.exposed_setLastManagementFeeAccrualTimestamp(leverageToken);
        skip(deltaT);

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        uint256 shares = feeManager.exposed_getManagementFeeShares(leverageToken);

        assertEq(shares, 0);
    }
}
