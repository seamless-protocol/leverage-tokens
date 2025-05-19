
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Id, IMorpho, MarketParams, Market, Position} from "@morpho-blue/interfaces/IMorpho.sol";

import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {ActionData} from "src/types/DataTypes.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract Donate is Script {
    ILeverageManager public leverageManager = ILeverageManager(DeployConstants.LEVERAGE_MANAGER);
    IMorpho public morpho = IMorpho(DeployConstants.MORPHO);

    

    function run() public {



      vm.startBroadcast(0x7191Aa3FcB54E23F05C411132179A277A34a81c6);

      IMorphoLendingAdapter la = IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(ILeverageToken(DeployConstants.LEVERAGE_TOKEN))));
      (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) = la.marketParams();


      MarketParams memory marketParams = MarketParams({
        loanToken: loanToken,
        collateralToken: collateralToken,
        oracle: oracle,
        irm: irm,
        lltv: lltv
      });

      morpho.borrow(marketParams, 1000e6, 0, address(la), address(la));



      // vm.etch(0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4, address(mo).code);

      // MockOracle mockOracle = MockOracle(0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4);
      // uint256 price = mockOracle.price();
      // console.log("price", price);




      // IWETH weth = IWETH(0x4200000000000000000000000000000000000006);
      // weth.deposit{value: 10e18}();
      // weth.approve(address(leverageManager), type(uint256).max);

      // ILeverageToken lt = ILeverageToken(DeployConstants.LEVERAGE_TOKEN);


      // ActionData memory previewMint = leverageManager.previewMint(lt, 1e18);
      // leverageManager.mint(lt, 1e18, 0);

      // LeverageTokenState memory state = leverageManager.getLeverageTokenState(lt);
      // console.log("collateral ratio", state.collateralRatio);

      vm.stopBroadcast();
    }
}

contract MockOracle {
  uint256 public x = 2468145093598160036862632774;

  function price () public view returns (uint256) {
    return 1868145093598160036862632774;
  }

  function setPrice (uint256 _price) public {
    x = _price;
  }
}

interface IWETH {
  function approve(address spender, uint256 amount) external;

  function deposit()external payable;
}
