# Seamless Leverage Tokens Flows

## Creating the Leverage Token

Anyone can create a leverage token by calling the `createLeverageToken` function in the Leverage Router and providing the following six things:

1. Leverage token symbol (e.g. "BTC3X")
2. Leverage token name (e.g. "BTC 3x Leverage Token")
3. Lending Adapter implenetation that adheres to the `ILendingAdapter` interface which is used to add/remove collateral and borrow/repay debt. There is no restriction on which lending protocl is used here as long as those assets are supported by morpho for flash loans
4. Rebalance Adapter implementation that adheres to the `IRebalanceAdapter` interface which is used to rebalance the leverage token. This is used to maintain the desired leverage multiplier. This implentation is also responsible for deteraming when a rebalance is needed
5. Mint Token Fee to charge when tokens are being minted, represented as percentage.
6. Burn Token Fee to charge when tokens are being burned, represented as percentage.

## weETH / WETH 17x Leverage Token Flows

### Mint

When a user mint weETH / WETH 17x Leverage Tokens they must provide weETH as collateral and they go through the following flow:

1. User approves weETH to be spent by the contract
2. User calls the mint functions in the Leverage Router which does the following:

   a. Calculates the amount of shares the user would get based on the amount of weETH they are depositing and the ratio of total shares and total equity

   ```
   new shares = equity * (total shares / total equity)
   ```

   b. Based on the new shares calculates the amount of weETH needed to borrow to achieve the desired WETH debt amount

   c. Flash loan the required amount of weETH minus the amount deposited by the user from Morpho

   d. Calculates manegment fee by minting some shares to the treasury (currently set to zero)

   e. Combines the flash loaned weETH and the weETH the user depositted and supplies it to Morpho vault as collateral

   f. Borrows the calculated amount of WETH in step b. from Morpho vault

   g. Calculates treasury fees by minting some share to the treasury (currently set to zero)

   h. Mints the calculated amount of shares in step a.

   i. Uses the borrowed WETH to deposit into etherfi and get the needed weETH to repay the flash loan

   j. If there any weETH left over (from the amount needed to relay flash loan), returns it to the user

   k. Transfers the shares to the user

   l. Repays the flash loan to Morpho

3. At this point the user has the leverage tokens in their wallet and the leverage position is open.

### Redeem

When a user redeems their weETH / WETH 17x Leverage Tokens they must provide the desired amount of leverage tokens to redeem and they go through the following flow:

1. User approves weETH / WETH 17x to be spent by the contract
2. User calls the redeem function in the Leverage Router which does the following:

   a. Calculates the amount of shares the user will loose based on the amount weETH they want to get back and the ratio of total shares and total equity

   ```
   shares to burn = equity * (total shares / total equity)
   ```

   b. Based on the shares to burn calculates the amount of WETH needed to get back the desired amount of weETH back

   c. Flash loans the calculated amount of WETH from Mprpho

   d. Calculates manegment fee by minting some shares to the treasury (currently set to zero)

   e. Burns the calculated amount of shares in step a.

   f. Calculates treasury fees by minting some share to the treasury (currently set to zero)

   g. Uses the flash loaned WETH to repay some of the debt in Morpho vault

   h. Removes the openned up weETH from Morpho vault

   i. Swaps the weETH to enough WETH to repay the flash loan using a DEX

   j. Send the excess weETH to the user

   k. Repays the flash loan to Morpho

3. At this point the user has the weETH in their wallet and the leverage position is closed.

### Rebalancing

Before rebalancing can be done, a relances needs to call `isEligibleForRebalance` in the rebalance adapter to check if the leverage token is eligible for rebalancing. This function needs the follwing info to determine if the rebalance is needed:

1. The leverage token address
2. Current state of the leverage token:

   a. Collateral amount
   b. Debt amount
   c. Equity amount
   d. Collateral ratio

3. Caller to the function

If the rebalance adapter returns true, the rebalancer must determine the amount of collateral and debt to add/remove to the leverage token to achieve the desired collateral ratio. Then the rebalancer calls the `rebalance` function which does the following:

1. Transfers the asset (either weETH or WETH) to the rebalance adapter to perform the list of actions determined by the rebalancer
2. Calls `isEligibleForRebalance` itself to make sure the leverage token is still eligible for rebalancing
3. Performs the list of actions determined by the rebalancer (one of add/remove collateral and borrow/repay debt)
4. Checks to makes sure state after rebalance is still valid (e.g. collateral ratio is still within the desired range)
5. Returns the excess collateral/debt to the rebalancer
