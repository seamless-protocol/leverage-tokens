// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract MockRebalanceModule {
    bool public isEligible;
    bool public isValid;

    mapping(IStrategy => uint256) public strategyMinCollateralRatio;
    mapping(IStrategy => uint256) public strategyMaxCollateralRatio;

    function mockSetStrategyMinCollateralRatio(IStrategy strategy, uint256 minCollateralRatio) public {
        strategyMinCollateralRatio[strategy] = minCollateralRatio;
    }

    function mockSetStrategyMaxCollateralRatio(IStrategy strategy, uint256 maxCollateralRatio) public {
        strategyMaxCollateralRatio[strategy] = maxCollateralRatio;
    }

    function mockIsEligibleForRebalance(IStrategy, bool _isEligible) public {
        isEligible = _isEligible;
    }

    function mockIsValidStateAfterRebalance(IStrategy, bool _isValid) public {
        isValid = _isValid;
    }

    function isEligibleForRebalance(IStrategy, StrategyState memory, address) external view returns (bool) {
        return isEligible;
    }

    function isStateAfterRebalanceValid(IStrategy, StrategyState memory) external view returns (bool) {
        return isValid;
    }
}
