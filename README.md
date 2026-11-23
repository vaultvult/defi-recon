# DeFi Recon Notes

Two protocols, two sessions, both negative. Published because the method transfers even when the targets don't, and because "we looked and found nothing" is data.

| Target | Chain | Outcome | Session |
|---|---|---|---|
| Pool Party V2 | Arbitrum / Robinhood Chain | No bug. 1.62% round-trip fee wall measured. | 1 |
| RNT Lend | Polygon | No bug reachable without admin rights. $55.5k stranded in aUSDC. | 2 |

## Why publish negatives

Most recon writeups only appear when something was found, so the field looks denser than it is. Two clean misses with the full reasoning attached are more useful than a third exploit thread, because they document where the seams aren't.

Both writeups include the dead ends deliberately.

## Pool Party V2 — summary

V2 alpha is on Arbitrum (hub) and Robinhood Chain (spoke). Base is where V1 was exploited; do not confuse them.

- 11 funds enumerated via `fundByNumber(uint256)` on the factory, ~$40 total TVL. Fund 7 (`0xa653F620EA8F5539Ed4bB55bE2977262FBa1F2dC`) selected at $19.15 NAV.
- Fee reality: the 12% wall is the protocol maximum. Fund 7 actually charges `flowFeeBps` 25 and `payoutFeeBps` 100 — 1.5% round trip.
- Dry drain on a Foundry fork measured **1.62% loss** on a $1 round trip. The fund pays out, it just costs more than it returns at that size.
- **Instant payouts settle inside `requestPayout`.** `claimPayout` only applies to `PayoutMode.Standard` and reverts `NoOpenPayoutRequest(address)` otherwise.
- Every NAV entry is token-backed and every rounding favours the fund. No mint-free path through deposit, payout, income-index or transit.
- Only survivor: a cents-scale JIT spoke-income leak (S-15), uneconomic below ~$1k.

Full writeup: [docs/pool-party-v2.md](docs/pool-party-v2.md)

## RNT Lend — summary

Aave V3.0.0 fork on Polygon, 108 reserves, $21M TVL at selection. Already drained $954,703 on 18 Nov 2026 by an admin swapping both stablecoin aToken proxies to a contract with a permissionless pull.

Oracle layer, fully mapped and hardened:

- Every reserve has its own aggregator, its own 837-byte proxy, and its own implementation — Chainlink `EACAggregatorProxy` shape with OCR `transmit` writes.
- 308-byte read-only stub implementations on the placeholder feeds; 9,571-byte `Ownable` implementations on the live ones.
- `RDO-6` serves a flat `1e20` at 18 decimals with `updatedAt 0` and `roundId 0` — never pushed, and the pool accepts it without a freshness check.
- Live feeds serve `~1.0897e20` on a moving external index over a static `1e20` phase base. The base is not the price.

aToken layer, closed:

- Both aToken proxies share implementation `0x7175160bfc3ab87f6248b97a3ca6ed6c2eab6e88`. EIP-1967 admin slot is `0x0`; no `upgradeTo` in the selector list.
- Full dispatch mapped (`0x1a`–`0x205`). No custom entry point. `0x18c39f17`, `0x7be53ca1`, `0x31873e2e` are all outbound call selectors, not functions.
- `rescueTokens` from an unprivileged EOA reverts `"1"` (`CALLER_NOT_POOL_ADMIN`, Aave V3.0.0 numeric error-string style). `ATOKEN_REVISION` is `1`.
- 55,529.636311 USDC still sits in aUSDC against 1,952,324 aUSDC supply — **$0.0284 of backing per aToken**. Remaining outflow paths are `onlyPool` or `onlyPoolAdmin`.

Full writeup: [docs/rnt-lend.md](docs/rnt-lend.md)

## Method

The reusable part: [method/recon-chain.md](method/recon-chain.md)

Provider, data provider, reserve enumeration, `getSourceOfAsset`, per-asset feed, EIP-1967 slot, implementation, selector dump, `cast 4byte`, guard trace. Roughly twenty minutes to replay on any Aave fork.

## Tooling

`cast` only: `call`, `code`, `codehash`, `codesize`, `storage`, `disassemble`, `4byte`, `block-number`, `wallet`. Foundry for fork rehearsal. No explorer API — Blockscout returned HTML and Alchemy's free tier caps `eth_getLogs` at 10 blocks, so everything here is `eth_call` and `eth_getStorageAt`.

## Layout

    docs/      per-target writeups
    method/    reusable recon chain
    opsec/     burner wallet and key handling
    recon/     raw captures, fund maps, selector dumps

## Caveats

Personal notes, unaudited, correct as of 2026-11-23. Fork rehearsal only — nothing here was executed against mainnet. Fee and price figures are point-in-time and move.

## Licence

MIT.
