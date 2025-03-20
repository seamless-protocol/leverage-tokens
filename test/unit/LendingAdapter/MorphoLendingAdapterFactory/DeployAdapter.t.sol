// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Internal imports
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {MorphoLendingAdapterFactoryBase} from "./MorphoLendingAdapterFactoryBase.t.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";

contract MorphoLendingAdapterFactoryDeployAdapterTest is MorphoLendingAdapterFactoryBase {
    function test_deployAdapter() public {
        address expectedAddress = factory.computeAddress(address(this), bytes32(0));

        vm.expectEmit(true, true, true, true);
        emit IMorphoLendingAdapterFactory.MorphoLendingAdapterDeployed(IMorphoLendingAdapter(expectedAddress));
        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        IMorphoLendingAdapter lendingAdapterA = factory.deployAdapter(defaultMarketId, bytes32(0));

        assertEq(address(lendingAdapterA), expectedAddress);
        assertEq(abi.encode(lendingAdapterA.morphoMarketId()), abi.encode(defaultMarketId));

        // Cannot initialize again
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        MorphoLendingAdapter(address(lendingAdapterA)).initialize(defaultMarketId);

        // Setup another market to deploy another adapter using a different market
        Id _marketId = Id.wrap("randomId");
        MarketParams memory _marketParams = MarketParams({
            loanToken: address(debtToken),
            collateralToken: address(collateralToken),
            oracle: makeAddr("oracle"),
            irm: makeAddr("irm"),
            lltv: 0.95e18
        });
        morpho.mockSetMarketParams(_marketId, _marketParams);

        expectedAddress = factory.computeAddress(address(this), bytes32(uint256(1)));

        vm.expectEmit(true, true, true, true);
        emit IMorphoLendingAdapterFactory.MorphoLendingAdapterDeployed(IMorphoLendingAdapter(expectedAddress));
        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        IMorphoLendingAdapter lendingAdapterB = factory.deployAdapter(_marketId, bytes32(uint256(1)));

        assertEq(address(lendingAdapterB), expectedAddress);
        assertEq(abi.encode(lendingAdapterB.morphoMarketId()), abi.encode(_marketId));

        // Cannot initialize again
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        MorphoLendingAdapter(address(lendingAdapterB)).initialize(_marketId);
    }
}
