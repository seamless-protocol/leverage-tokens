// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library DeployConstants {
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant SEAMLESS_TIMELOCK_SHORT = 0x639d2dD24304aC2e6A691d8c1cFf4a2665925fee;
    address public constant SEAMLESS_TREASURY = 0x639d2dD24304aC2e6A691d8c1cFf4a2665925fee;
    address public constant ETHERFI_L2_MODE_SYNC_POOL = 0xc38e046dFDAdf15f7F56853674242888301208a5;

    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant WEETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;

    // TODO: Update this after deployment
    address public constant LEVERAGE_MANAGER = address(0);
    address public constant LENDING_ADAPTER_FACTORY = address(0);
    address public constant ETHERFI_LEVERAGE_ROUTER = address(0);
}
