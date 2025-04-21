// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Local imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManager} from "src/FeeManager.sol";
import {FeeManagerHarness} from "test/unit/harness/FeeManagerHarness.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";

contract FeeManagerTest is Test {
    uint256 public constant SECONDS_ONE_YEAR = 31536000;

    address public feeManagerRole = makeAddr("feeManagerRole");
    FeeManagerHarness public feeManager;

    ILeverageToken leverageToken = ILeverageToken(address(new MockERC20()));

    address treasury = makeAddr("treasury");

    function setUp() public virtual {
        address feeManagerImplementation = address(new FeeManagerHarness());
        address feeManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            feeManagerImplementation, abi.encodeWithSelector(FeeManagerHarness.initialize.selector, address(this))
        );

        feeManager = FeeManagerHarness(feeManagerProxy);
        feeManager.grantRole(feeManager.FEE_MANAGER_ROLE(), feeManagerRole);

        vm.prank(feeManagerRole);
        feeManager.setTreasury(treasury);
    }

    function test_setUp() public view virtual {
        bytes32 expectedSlot = keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.FeeManager")) - 1))
            & ~bytes32(uint256(0xff));

        assertTrue(feeManager.hasRole(feeManager.FEE_MANAGER_ROLE(), feeManagerRole));
        assertEq(feeManager.exposed_getFeeManagerStorageSlot(), expectedSlot);
        assertEq(feeManager.getTreasury(), treasury);
    }

    function test_feeManagerInit_RevertsIfNotInitializer() public {
        vm.expectRevert(Initializable.NotInitializing.selector);
        feeManager.__FeeManager_init(address(this));
    }

    function _setTreasuryActionFee(address caller, ExternalAction action, uint256 fee) internal {
        vm.prank(caller);
        feeManager.setTreasuryActionFee(action, fee);
    }

    function _setTreasury(address caller, address _treasury) internal {
        vm.prank(caller);
        feeManager.setTreasury(_treasury);
    }
}
