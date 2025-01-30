// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {SwapperBaseTest} from "./SwapperBase.t.sol";

contract SetSwapper is SwapperBaseTest {
    function test_setProvider() public {
        swapper.setProvider(ISwapper.Provider.LiFi);
        assertEq(uint256(swapper.provider()), uint256(ISwapper.Provider.LiFi));
    }
}
