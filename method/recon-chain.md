# Recon chain

Replayable on any Aave fork. Twenty minutes.

    POOL=<pool>
    DP=<data provider>
    O=<oracle>
    ME=<burner>

    # 1. enumerate reserves
    cast call $DP 'getAllReservesTokens()((string,address)[])' --rpc-url "$RPC"

    # 2. config per reserve, rank by LTV and collateral size
    cast call $DP 'getReserveConfigurationData(address)(uint256,uint256,uint256,uint256,uint256,bool,bool,bool,bool,bool)' $ASSET --rpc-url "$RPC"

    # 3. oracle source per asset
    cast call $O 'getSourceOfAsset(address)(address)' $ASSET --rpc-url "$RPC"

    # 4. walk the source: EIP-1967 impl slot, then the impl
    cast storage $SRC 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$RPC"
    cast code $IMPL --rpc-url "$RPC" > src.hex
    cast disassemble "$(cat src.hex)" > dis.txt

    # 5. what is exposed, and what guards it
    grep -oE 'PUSH4 0x[0-9a-f]{8}' dis.txt | sort -u
    grep -n 'CALLER\|ORIGIN\|SSTORE\|SLOAD' dis.txt
    for s in SELECTORS; do cast 4byte $s; done

    # 6. probe access control without spending
    cast call $SRC 'SETTER(uint256)' 1 --from $ME --rpc-url "$RPC"

## Signals

- A selector followed by `PUSH1 0xe1 SHL` is an outbound call selector, not an entry point. Do not chase it.
- A selector absent from the dispatch table is not callable.
- `revert("1")` on an Aave V3.0.0 base is `CALLER_NOT_POOL_ADMIN`.
- EIP-1967 admin slot `0x0` plus no `upgradeTo` means upgrade authority lives elsewhere, which is not a public path.
- No `SSTORE` anywhere in the contract means nothing is writable there. Look one hop out.

## Rank targets by

1. Permissionless `addReserve` or `initReserve` accepting a caller-supplied oracle.
2. aToken outflow paths that are neither `onlyPool` nor `onlyPoolAdmin`.
3. Missing freshness checks on a feed with `updatedAt 0`.
4. TVL above $1M, so the ceiling is worth the gas.

## Anti-patterns

- Paying for an explorer API. Blockscout serves HTML and Alchemy free tier caps `eth_getLogs` at 10 blocks. `eth_call` and `eth_getStorageAt` are enough.
- Trusting a documented library address. Run `cast codesize` first; `0xc5d246...` is keccak of empty.
- Building a harness before checking TVL.
