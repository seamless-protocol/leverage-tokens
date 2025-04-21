// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerTest} from "./LeverageManager.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {TokenTransfer} from "src/types/DataTypes.sol";

contract TransferTokensTest is LeverageManagerTest {
    function test_transferTokens_FromLeverageManager() public {
        ERC20Mock token1 = new ERC20Mock();

        uint256 token1BalanceBefore = 100 ether;

        token1.mint(address(leverageManager), token1BalanceBefore);

        uint256 token1TransferAmount = 50 ether;

        TokenTransfer memory transfer = TokenTransfer({token: address(token1), amount: token1TransferAmount});

        leverageManager.exposed_transferTokens(transfer, address(leverageManager), address(this));

        assertEq(token1.balanceOf(address(this)), token1TransferAmount);
        assertEq(token1.balanceOf(address(leverageManager)), token1BalanceBefore - token1TransferAmount);
    }

    function test_transferTokens_ToLeverageManager() public {
        ERC20Mock token1 = new ERC20Mock();

        uint256 token1BalanceBefore = 100 ether;

        token1.mint(address(this), token1BalanceBefore);

        uint256 token1TransferAmount = 50 ether;

        TokenTransfer memory transfer = TokenTransfer({token: address(token1), amount: token1TransferAmount});

        token1.approve(address(leverageManager), token1TransferAmount);

        leverageManager.exposed_transferTokens(transfer, address(this), address(leverageManager));

        assertEq(token1.balanceOf(address(leverageManager)), token1TransferAmount);
        assertEq(token1.balanceOf(address(this)), token1BalanceBefore - token1TransferAmount);
    }
}
