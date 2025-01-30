// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {SwapperBaseTest} from "./SwapperBase.t.sol";

contract SetProviderTest is SwapperBaseTest {
    function test_setProvider() public {
        vm.prank(manager);
        swapper.setProvider(ISwapper.Provider.LiFi);
        assertEq(uint256(swapper.getProvider()), uint256(ISwapper.Provider.LiFi));
    }

    function testFuzz_setProvider_RevertIf_CallerIsNotManager(address caller) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, swapper.MANAGER_ROLE()
            )
        );
        vm.prank(caller);
        swapper.setProvider(ISwapper.Provider.LiFi);
    }
}
