// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";
import {LeverageTokenState, ActionData} from "src/types/DataTypes.sol";

import {LeverageManagerTestUtils} from "../../LeverageManagerTestUtils.t.sol";

contract LeverageManagerTest is IntegrationTestBase, LeverageManagerTestUtils {
    function testFork_setUp() public view virtual override {
        assertEq(address(leverageManager.getLeverageTokenCollateralAsset(leverageToken)), address(CBBTC));
        assertEq(address(leverageManager.getLeverageTokenDebtAsset(leverageToken)), address(USDC));
    }

    function _deposit(address caller, uint256 collateralToDeposit, uint256 minShares)
        internal
        returns (ActionData memory)
    {
        return _deposit(leverageManager, leverageToken, CBBTC, caller, collateralToDeposit, minShares);
    }

    function _mint(address caller, uint256 sharesToMint, uint256 maxCollateral) internal returns (ActionData memory) {
        return _mint(leverageManager, leverageToken, CBBTC, caller, sharesToMint, maxCollateral);
    }

    function _redeem(address caller, uint256 shares, uint256 minCollateral, uint256 debtToRepay) internal {
        _redeem(leverageManager, leverageToken, USDC, caller, shares, minCollateral, debtToRepay);
    }

    function _withdraw(address caller, uint256 collateral, uint256 maxShares, uint256 debtToRepay) internal {
        _withdraw(leverageManager, leverageToken, USDC, caller, collateral, maxShares, debtToRepay);
    }

    function getLeverageTokenState() internal view returns (LeverageTokenState memory) {
        return getLeverageTokenState(leverageManager, leverageToken);
    }
}
