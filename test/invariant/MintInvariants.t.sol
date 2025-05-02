// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.26;

// // Forge imports
// import {stdMath} from "forge-std/StdMath.sol";

// // Dependency imports
// import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// // Internal imports
// import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
// import {LeverageTokenState} from "src/types/DataTypes.sol";
// import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
// import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";
// import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";

// // Mint:
// // - Collateral ratio must equal the collateral ratio before the mint (within some allowed error margin,
// //   depends on size of LT before and amount of equity added)
// // - Shares minted to the user must be equal to the amount of equity added to the LT, minus the token action fee and treasury fee
// // - Shares before the mint must be worth greater than or equal to the value before the mint (share price >= before)

// // Redeem:
// // - Collateral ratio must equal the collateral ratio before the redeem (within some allowed error margin,
// // - Shares redeemed from the user must be equal to the amount of equity added to the LT, minus the token action fee and the treasury fee
// // - Shares before the redeem must be worth greater than or equal to the value before the redeem (share price >= before)

// contract MintInvariants is InvariantTestBase {
// // function invariant_mint() public view {
// //     LeverageManagerHandler.LeverageTokenStateData memory stateBefore =
// //         leverageManagerHandler.getLeverageTokenStateBefore();
// //     if (stateBefore.actionType != LeverageManagerHandler.ActionType.Mint) {
// //         return;
// //     }

// //     LeverageManagerHandler.MintActionData memory mintData =
// //         abi.decode(stateBefore.actionData, (LeverageManagerHandler.MintActionData));
// //     ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(mintData.leverageToken);
// // }
// }
