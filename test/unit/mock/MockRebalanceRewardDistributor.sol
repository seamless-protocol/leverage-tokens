// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract MockRebalanceRewardDistributor {
    using SignedMath for int256;
    using SafeCast for uint256;

    function computeRebalanceReward(address, StrategyState memory stateBefore, StrategyState memory stateAfter)
        external
        pure
        returns (uint256 reward)
    {
        uint256 debtChange = (stateAfter.debt.toInt256() - stateBefore.debt.toInt256()).abs();
        return debtChange / 10;
    }
}
