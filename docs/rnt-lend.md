# RNT Lend

**Outcome: negative for an unprivileged attacker.** Every outflow path is `onlyPool` or `onlyPoolAdmin`. The 18 Nov window is closed.

## Incident

18 Nov 2026, $954,703. An admin upgraded the USDT and USDC aToken proxies to a contract with a permissionless pull, then swept. $454.8k to MEV bots in two txs, $499.9k from Reental-associated wallets. Pool paused 16:55 UTC.

## What was checked

Oracle: aggregator per reserve, 837-byte proxy per reserve, per-reserve implementation. Chainlink `EACAggregatorProxy` shape. `confirmAggregator`, `proposeAggregator`, `phaseAggregators`, `phaseId`, `hasAccess`, `accessController` all present. Writes are OCR `transmit` — not reachable.

Two implementation generations coexist:

| | size | writes | shape |
|---|---|---|---|
| placeholder feeds | 308 B | none | four getters, `SLOAD 0` only |
| live feeds | 9,571 B | 8 `SSTORE`, 15 `CALLER` | `Ownable`, real arithmetic |

Storage layout recovered: slot 0 packed `(impl, 0x0001)`, slot 1 static base `1e20`, slot 2 decimals `18`, slot 3 description plus length.

`RDO-6` is a placeholder: flat `1e10` at the aggregator, `updatedAt 0`, `roundId 0`. The pool serves it without a freshness check. Live feeds serve `~1.0897e20` because the answer is `slot1` times an external index; slot 1 never moved across three samples 90 seconds apart.

## aToken layer

Both proxies share `0x7175160bfc3ab87f6248b97a3ca6ed6c2eab6e88`. EIP-1967 admin slot `0x0`, no `upgradeTo` or `upgradeToAndCall`. Full dispatch mapped, no custom entry point.

`0x18c39f17` is unmatched in 4byte and absent from the dispatch table. It is built with `PUSH1 0xe1 SHL` and is an outbound selector, same as `0x7be53ca1` (`isPoolAdmin`) and `0x31873e2e` (`handleAction`).

`rescueTokens(USDC, attacker, 1)` from an unprivileged EOA reverts `"1"`. In Aave V3.0.0 numeric-string style, `1` is `CALLER_NOT_POOL_ADMIN`. `ATOKEN_REVISION` is `1`.

## The stranded balance

    aUSDC USDC balance   55,529.636311
    aUSDC totalSupply    1,952,324.347805
    backing per aToken   $0.0284

Anyone holding aUSDC is down about 97%. Two consequences:

1. A DEX quote above about $0.03 is a clean short with no admin or oracle dependency.
2. Supplying fresh USDC and withdrawing immediately still clears, because the queue is short. But supplying and borrowing 75% nets 75% cash against a claim worth 2.8%, so it is not free money.

## Open questions

- ACL manager and PoolAddressesProvider both revert on these proxies. Admin identity unresolved.
- Whether the pool is paused. `paused()` is absent (pre-V3.1 fork).
- Whether a `setPrice` exists on the 9,571-byte feed implementation, and what it guards.
