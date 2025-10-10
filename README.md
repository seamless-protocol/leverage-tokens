# Seamless Leverage Tokens

The Seamless Leverage Token protocol is comprised of smart contracts that provide ERC20 tokenized representations of any leveraged position between 2 assets on a blockchain. If a lending market exists between 2 assets then a Leverage Token can be permissionlessly created for the leveraged position.

## Getting Started

This project uses [Foundry](https://book.getfoundry.sh/) for development.

Install dependencies: `forge install`

Run forge tests: `forge test`

Build: `forge build`

## Architecture

The protocol is composed of modular contracts that abstract away the complexities of managing leveraged positions. These components are designed to be flexible, composable, and upgradeable, making it easy to integrate new lending markets, rebalancing strategies, or token configurations. See the [DeepWiki](https://deepwiki.com/seamless-protocol/leverage-tokens) for more.

## Permissionless Creation
Leverage Tokens within the Seamless Protocol are designed to be fully permissionless. This means:

- **Anyone can create a new Leverage Token:** There are no restrictions or allowlists for token creation. Users, developers, or even external parties can deploy new Leverage Tokens at any time.

- **Potential for Malicious Tokens:** Because creation is open, it is possible for malicious actors to deploy Leverage Tokens with configurations or parameters intended to deceive users or exploit vulnerabilities. Participants should exercise caution and verify the legitimacy and configuration of any Leverage Token before interacting with it.

## Inherited Risks from Underlying Platforms
Leverage Tokens are built to interact with various DeFi protocols through adapters. As a result:

- **Exposure to Adapter Risks:** Each Leverage Token inherits the technical and economic risks of any underlying lending or DeFi platform it integrates with via adapters. If an adapter connects to a platform with vulnerabilities, those risks are passed through to the Leverage Token and its users.

- **No Isolation from Platform Failures:** Issues such as smart contract bugs, oracle failures, insolvency, or governance attacks on underlying platforms can directly impact the safety and value of the Leverage Token.

- **Dynamic Risk Profile:** The risk profile of each Leverage Token may change over time as underlying protocols are upgraded, attacked, or experience market volatility.

### LeverageManager

The LeverageManager is the core singleton contract used for creating and maintaining leverage positions involving two assets: one serving as collateral and the other as debt. It does not handle any swapping or other asset-trading logic; instead, it only relies on price data (i.e., the relative price of the two assets) to validate and oversee the leverage position.

### LeverageToken

LeverageTokens are ERC20 tokens that represent a share of a specific leveraged position. These are deployed permissionlessly via the LeverageManager.

Each LeverageToken has the following properties:

- ERC20-compliant: Balances represent proportional ownership of a leveraged position.
- Immutable configuration: Once deployed, the position’s parameters cannot be modified.
- Configured with adapters:
  - A LendingAdapter, which handles interaction with the external lending protocol.
  - A RebalanceAdapter, which defines rebalance conditions and logic.

### LendingAdapter

LendingAdapters are periphery contracts responsible for interfacing with external lending protocols (e.g., Morpho). Each LeverageToken is configured with a LendingAdapter at the time of creation and must implement the minimal interface `ILendingAdapter`.

Key responsibilities:

- Own the underlying debt and collateral positions.
- Abstract lending protocol-specific logic behind a standard interface for the LeverageManager to consume to manage the positions.

### RebalanceAdapter

RebalanceAdapters are periphery contracts that facilitate rebalance actions and rules for LeverageTokens. Each LeverageToken is configured with a RebalanceAdapter at the time of creation. The RebalanceAdapter must implement the minimal interface `IRebalanceAdapterBase` which includes the following:

- isEligibleForRebalance: Returns true if the token meets conditions to trigger a rebalance
- isStateValidAfterRebalance: Returns true if the LeverageToken’s state is valid after a rebalance
- getLeverageTokenInitialCollateralRatio: Returns the collateral ratio that should be used when the LeverageToken is empty / total shares == 0
- postLeverageTokenCreation: Post LeverageToken creation hook. Executed during LeverageToken creation in LeverageManager

## Upgrades

All contracts are immutable except LeverageManager, LeverageToken, RebalanceAdapter, and BeaconProxyFactory. During deployment and upgrade of these contracts, OZ's foundry-upgrades plugin is used. For safe upgrades, the custom directive `@custom:oz-upgrades-from <reference contract>` must be added on the new implementation. More details on how to use OZ's upgrades plugin can be found [here](https://docs.openzeppelin.com/upgrades-plugins/foundry-upgrades#upgrade_a_proxy_or_beacon).

## Audits

Audits reports can be found in the [audits](./audits/) folder.

## Security

To report any issues, please contact security@seamlessprotocol.com.

## Deployed Contracts - Ethereum Mainnet

### Core

- LeverageToken implementation: `0xfE9101349354E278970489F935a54905DE2E1856`
- LeverageToken factory proxy: `0x603Da735780e6bC7D04f3FB85C26dccCd4Ff0a82`
- LeverageManager implementation: `0x9D04f65b58cED1fddef50AEc8b0b3d64fE64220E`
- LeverageManager proxy: `0x5C37EB148D4a261ACD101e2B997A0F163Fb3E351`
- MorphoLendingAdapterFactory: `0xce05FbEd9260810Bdded179ADfdaf737BE7ded71`
- MorphoLendingAdapter implementation: `0x00c66934EBCa0F2A845812bC368B230F6da11A5C`
- Guardian: `0x90E8C75e2917E3C2F284F6922Df6c16F7C03123c`

### Periphery

- MulticallExecutor: `0x16D02Ebd89988cAd1Ce945807b963aB7A9Fd22E1`
- VeloraAdapter: `0xc4E5812976279cBcec943A6a148C95eAAC7Db6BA`
- LeverageRouter: `0xb0764dE7eeF0aC69855C431334B7BC51A96E6DbA`
- PricingAdapter: `0x44CCEBEA0dAc17105e91a59E182f65f8D176c88f`
- LeverageTokenDeploymentBatcher: `0x4466D52b714Ef32657db89ec61FAB1b7E30A0352`

## Deployed Contracts - Base Mainnet

### Core

- LeverageToken implementation: `0x603Da735780e6bC7D04f3FB85C26dccCd4Ff0a82`
- LeverageToken factory proxy: `0xE0b2e40EDeb53B96C923381509a25a615c1Abe57`
- LeverageManager implementation: `0xfE9101349354E278970489F935a54905DE2E1856`
- LeverageManager proxy: `0x38Ba21C6Bf31dF1b1798FCEd07B4e9b07C5ec3a8`
- MorphoLendingAdapterFactory: `0xDd33419F0c01879a23051edbcdA997A0f9E68e61`
- MorphoLendingAdapter implementation: `0x585cc1c8AF5C8aD79C64ac66D264590A3Ff65C51`
- RebalanceAdapter implementation: `0xD923b2522E1f369e207d151cFE6A1BCd8EC24912`

### Periphery

- MulticallExecutor: `0x9D04f65b58cED1fddef50AEc8b0b3d64fE64220E`
- VeloraAdapter: `0x5C37EB148D4a261ACD101e2B997A0F163Fb3E351`
- LeverageRouter: `0x00c66934EBCa0F2A845812bC368B230F6da11A5C`
- PricingAdapter: `0xce05FbEd9260810Bdded179ADfdaf737BE7ded71`
