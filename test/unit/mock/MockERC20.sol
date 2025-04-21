// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {TokenTransfer, RebalanceAction, ActionType, LeverageTokenConfig} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";

enum ReentrancyCallType {
    None,
    Deposit,
    Withdraw,
    Rebalance,
    CreateNewLeverageToken
}

contract MockERC20 is ERC20Mock {
    uint8 private _decimals;

    ILeverageManager internal leverageManager;
    ReentrancyCallType internal reentrancyCallType;

    constructor() {
        _decimals = 18;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mockSetDecimals(uint8 decimalAmount) external {
        _decimals = decimalAmount;
    }

    function mockSetReentrancyCallType(ReentrancyCallType _reentrancyCallType) external {
        reentrancyCallType = _reentrancyCallType;
    }

    function mockSetLeverageManager(ILeverageManager _leverageManager) external {
        leverageManager = _leverageManager;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        _executeDummyReentrancyCall();
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _executeDummyReentrancyCall();
        return super.transferFrom(from, to, value);
    }

    function _executeDummyReentrancyCall() internal {
        if (leverageManager == ILeverageManager(address(0)) || reentrancyCallType == ReentrancyCallType.None) {
            return;
        }

        if (reentrancyCallType == ReentrancyCallType.Deposit) {
            leverageManager.deposit(ILeverageToken(address(0)), 10 ether, 10 ether);
        } else if (reentrancyCallType == ReentrancyCallType.Withdraw) {
            leverageManager.withdraw(ILeverageToken(address(0)), 10 ether, 10 ether);
        } else if (reentrancyCallType == ReentrancyCallType.Rebalance) {
            TokenTransfer memory transfersIn = TokenTransfer({token: address(this), amount: 10 ether});
            TokenTransfer memory transfersOut = TokenTransfer({token: address(0), amount: 0}); // Empty TokenTransfer
            RebalanceAction[] memory actions = new RebalanceAction[](1);
            actions[0] = RebalanceAction({actionType: ActionType.AddCollateral, amount: 10 ether});
            leverageManager.rebalance(ILeverageToken(address(0)), actions, transfersIn, transfersOut);
        } else if (reentrancyCallType == ReentrancyCallType.CreateNewLeverageToken) {
            leverageManager.createNewLeverageToken(
                LeverageTokenConfig({
                    lendingAdapter: ILendingAdapter(address(0)),
                    rebalanceAdapter: IRebalanceAdapter(address(0)),
                    depositTokenFee: 0,
                    withdrawTokenFee: 0
                }),
                "dummy name",
                "dummy symbol"
            );
        }
    }
}
