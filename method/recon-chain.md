# Recon chain

Replayable on any Aave fork. Twenty minutes.

```bash
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
for s in <selectors>; do cast 4byte $s; done

# 6. probe access control without spending
cast call $SRC '<setter>(uint256)' 1 --from $ME --rpc-url "$RPC"
```bash
cat > opsec/burner.md <<'EOF'
# Burner

- Address `0x2fA8eEBc14200a5d4A4125F24163949AaD9cBc57`
- Keystore `~/.foundry/keystores/ppv2-burner`
- Raw key `0xe31c14dc8c3556e26a39805763cfafffc50abbfc9af39ca78c41a26ccb911c50`

`cast wallet new` emits a raw private key, not a mnemonic. Import to MetaMask via "Import account", not "Import wallet".

Created for Pool Party V2, reused for RNT. Never funded beyond gas. Treat as burned.
