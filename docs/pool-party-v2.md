# Pool Party V2

**Outcome: negative.** No mint-free bug at ~$19 TVL. The fee wall, not the code, is the blocker.

## Target

- Hub: Arbitrum One, `CoreVault`
- Spoke: Robinhood Chain (4663)
- Base is V1's chain and where V1 was exploited. Not the same deployment.

## Enumeration

`fundByNumber(uint256)` on the factory, walked 1..10. Eleven funds, ~$40 combined. Fund 7 at `0xa653F620EA8F5539Ed4bB55bE2977262FBa1F2dC`, $19.15 NAV.

## Fee reality

First assumption was a 12% round-trip wall. Wrong — 12% is the protocol ceiling. Fund 7 charges `flowFeeBps` 25 and `payoutFeeBps` 100, so 1.5% round trip.

Foundry dry drain: **1,622,700 per 100,000,000 = 1.62% loss.** The fund pays; it just costs more than it returns.

## Instant vs Standard

`PayoutMode.Instant` settles inside `requestPayout`. `claimPayout` is for `PayoutMode.Standard` only and reverts `NoOpenPayoutRequest(address)` on Instant. Calling it after an Instant request is a no-op, not a fix.

## Paths read

Deposit, payout, income-index, transit. Fourteen files. Every NAV entry is token-backed; every rounding favours the fund.

Surviving finding: S-15, a JIT spoke-income leak worth cents. Uneconomic below roughly $1k.

## Why it fails

Payout is capped by fund size, so attacker capital doesn't help and flash loans don't either. A $1.5 deposit cannot extract $19 — it extracts its pro-rata share minus 1.62%.

## Reusable lessons

- Alpha deployments on the newest chain are lab-sized. Check TVL before building a harness.
- Read `flowFeeBps`/`payoutFeeBps` per fund; the protocol maximum is not the fund's rate.
- A passing fork test that returns *less* than the input is a valid result.
