// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILeverageManager} from "./interfaces/ILeverageManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// TODO: Remove abstract once all functions are implemented
abstract contract LeverageManager is ILeverageManager, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
