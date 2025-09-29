// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// Forge imports
import {Script, console} from "forge-std/Script.sol";

/// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {DeployConstants} from "./DeployConstants.sol";

/// @notice This script transfers admin and fee manager roles to new addresses, and updates the treasury. It does the following:
///   - Updates the treasury for the LeverageManager
///   - Revokes the `FEE_MANAGER_ROLE` role from the sender
///   - Grants the `FEE_MANAGER_ROLE` to an address
///   - Grants the `DEFAULT_ADMIN_ROLE` to an address
///   - Revokes the `DEFAULT_ADMIN_ROLE` role from the sender
///   - Transfers the ownership of the LeverageTokenFactory to an address
/// @dev This script must be executed by an address holding the `DEFAULT_ADMIN_ROLE` for the LeverageManager. This address must
/// also be the current owner of the LeverageTokenFactory.
/// @dev The `newAdmin`, `newFeeManager`, and `newTreasury` addresses must be set in the script to the addresses to transfer the roles to.
contract TransferAdminAndFeeManagerRoles is Script {
    /// @dev Address to grant the admin role to for the LeverageManager and the owner of the LeverageTokenFactory
    address public newAdmin = address(0xBEEF);

    /// @dev Address to grant the fee manager role to for the LeverageManager
    address public newFeeManager = address(0xBEEF);

    /// @dev Address to set the treasury to for the LeverageManager
    address public newTreasury = address(0xBEEF);

    function run() public {
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);
        console.log("Sender: ", msg.sender);
        console.log("New admin: ", newAdmin);

        LeverageManager leverageManager = LeverageManager(DeployConstants.LEVERAGE_MANAGER);
        BeaconProxyFactory leverageTokenFactory = BeaconProxyFactory(DeployConstants.LEVERAGE_TOKEN_FACTORY);

        vm.startBroadcast();

        // Grant fee manager role to the sender so that they can update the treasury address
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), msg.sender);
        require(
            leverageManager.hasRole(leverageManager.FEE_MANAGER_ROLE(), msg.sender),
            "LeverageManager fee manager role not granted to sender"
        );
        console.log("LeverageManager fee manager role granted to: ", msg.sender);

        // Set the new treasury for the LeverageManager
        leverageManager.setTreasury(newTreasury);
        require(leverageManager.getTreasury() == newTreasury, "LeverageManager treasury not set to new treasury");
        console.log("LeverageManager treasury set to: ", newTreasury);

        // Revoke fee manager from the sender for the LeverageManager
        leverageManager.revokeRole(leverageManager.FEE_MANAGER_ROLE(), msg.sender);
        require(
            !leverageManager.hasRole(leverageManager.FEE_MANAGER_ROLE(), msg.sender),
            "LeverageManager fee manager role not revoked from sender"
        );
        console.log("LeverageManager fee manager role revoked from: ", msg.sender);

        // Grant fee manager role to the new fee manager
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), newFeeManager);
        require(
            leverageManager.hasRole(leverageManager.FEE_MANAGER_ROLE(), newFeeManager),
            "LeverageManager fee manager role not granted to new fee manager"
        );
        console.log("LeverageManager fee manager role granted to: ", newFeeManager);

        // Grant admin role to the new admin for the LeverageManager
        leverageManager.grantRole(leverageManager.DEFAULT_ADMIN_ROLE(), newAdmin);
        require(
            leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), newAdmin),
            "LeverageManager admin role not granted to new admin"
        );
        console.log("LeverageManager admin role granted to: ", newAdmin);

        // Revoke admin from the sender for the LeverageManager
        leverageManager.revokeRole(leverageManager.DEFAULT_ADMIN_ROLE(), msg.sender);
        require(
            !leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), msg.sender),
            "LeverageManager admin role not revoked from sender"
        );
        console.log("LeverageManager admin role revoked from: ", msg.sender);

        // Transfer ownership of the LeverageTokenFactory to the new admin
        leverageTokenFactory.transferOwnership(newAdmin);
        require(leverageTokenFactory.owner() == newAdmin, "LeverageTokenFactory ownership not transferred to new admin");
        console.log("LeverageTokenFactory ownership transferred to: ", newAdmin);

        vm.stopBroadcast();
    }
}
