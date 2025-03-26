// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {LeverageTokenConfig} from "src/types/DataTypes.sol";
import {LeverageToken} from "src/LeverageToken.sol";

contract CreateNewLeverageTokenTest is LeverageManagerBaseTest {
    function testFuzz_CreateNewLeverageToken(
        LeverageTokenConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) public {
        config.depositTokenFee = bound(config.depositTokenFee, 0, _MAX_FEE());
        config.withdrawTokenFee = bound(config.withdrawTokenFee, 0, _MAX_FEE());

        address expectedLeverageTokenAddress = leverageTokenFactory.computeProxyAddress(
            address(leverageManager),
            abi.encodeWithSelector(LeverageToken.initialize.selector, address(leverageManager), name, symbol),
            0
        );

        // Check if event is emitted properly
        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.LeverageTokenCreated(
            ILeverageToken(expectedLeverageTokenAddress), IERC20(collateralAsset), IERC20(debtAsset), config
        );

        _createNewLeverageToken(manager, config, collateralAsset, debtAsset, name, symbol);

        // Check name of the leverage token
        assertEq(IERC20Metadata(expectedLeverageTokenAddress).name(), name);
        assertEq(IERC20Metadata(expectedLeverageTokenAddress).symbol(), symbol);

        // Check if the leverage token core is set correctly
        LeverageTokenConfig memory configAfter = leverageManager.getLeverageTokenConfig(leverageToken);
        assertEq(address(configAfter.lendingAdapter), address(config.lendingAdapter));
        assertEq(address(configAfter.rebalanceModule), address(config.rebalanceModule));

        assertEq(configAfter.depositTokenFee, config.depositTokenFee);
        assertEq(configAfter.withdrawTokenFee, config.withdrawTokenFee);

        assertEq(address(leverageManager.getLeverageTokenCollateralAsset(leverageToken)), collateralAsset);
        assertEq(address(leverageManager.getLeverageTokenDebtAsset(leverageToken)), debtAsset);

        assertEq(leverageManager.getIsLendingAdapterUsed(address(config.lendingAdapter)), true);
        assertEq(leverageManager.getLeverageTokenTargetCollateralRatio(leverageToken), config.targetCollateralRatio);
        assertEq(
            address(leverageManager.getLeverageTokenRebalanceModule(leverageToken)), address(config.rebalanceModule)
        );
    }

    function test_CreateNewLeverageToken_RevertIf_LendingAdapterAlreadyInUse(
        LeverageTokenConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) public {
        config.depositTokenFee = bound(config.depositTokenFee, 0, _MAX_FEE());
        config.withdrawTokenFee = bound(config.withdrawTokenFee, 0, _MAX_FEE());

        _createNewLeverageToken(manager, config, collateralAsset, debtAsset, name, symbol);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.LendingAdapterAlreadyInUse.selector, address(config.lendingAdapter))
        );
        _createNewLeverageToken(manager, config, collateralAsset, debtAsset, name, symbol);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_CreateNewLeverageToken_RevertIf_LendingAdapterUnauthorized(
        address authorizedCaller,
        address unauthorizedCaller,
        LeverageTokenConfig memory config,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(authorizedCaller != unauthorizedCaller);

        vm.mockCall(
            address(config.lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.owner.selector),
            abi.encode(authorizedCaller)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageManager.LendingAdapterSenderUnauthorized.selector,
                address(config.lendingAdapter),
                unauthorizedCaller
            )
        );
        vm.prank(unauthorizedCaller);
        leverageManager.createNewLeverageToken(config, name, symbol);
    }
}
