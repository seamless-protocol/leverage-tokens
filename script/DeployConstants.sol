// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library DeployConstants {
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant SEAMLESS_GOVERNOR_SHORT = 0x8768c789C6df8AF1a92d96dE823b4F80010Db294;
    address public constant SEAMLESS_GOVERNOR_LONG = 0x04faA2826DbB38a7A4E9a5E3dB26b9E389E761B6;
    address public constant SEAMLESS_TREASURY = 0x04faA2826DbB38a7A4E9a5E3dB26b9E389E761B6;

    // TODO: Update this after deployment
    address public constant LEVERAGE_MANAGER = address(0);
    address public constant LENDING_ADAPTER_FACTORY = address(0);
}
