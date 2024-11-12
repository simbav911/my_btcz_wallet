# BitcoinZ Core Parameters

## Network Magic Numbers
```yaml
Parameter:
  name: Network Magic (Mainnet)
  value: [0x24, 0xe9, 0x27, 0x64]
  location: src/chainparams.cpp
  purpose: Network packet identification
  constraints: Must match for peer connections
```

## Network Ports
```yaml
Parameter:
  name: Default Port (Mainnet)
  value: 1989
  location: src/chainparams.cpp
  purpose: P2P network communication
  constraints: None

Parameter:
  name: Default Port (Testnet)
  value: 11989
  location: src/chainparams.cpp
  purpose: Testnet P2P communication
  constraints: None
```

## Address Formats
```yaml
Parameter:
  name: Public Key Address Prefix
  value: [0x1C,0xB8]
  location: src/chainparams.cpp
  purpose: Guarantees addresses start with "t1"
  constraints: Base58 encoded

Parameter:
  name: Script Address Prefix
  value: [0x1C,0xBD]
  location: src/chainparams.cpp
  purpose: Guarantees addresses start with "t3"
  constraints: Base58 encoded

Parameter:
  name: Private Key Prefix
  value: [0x80]
  location: src/chainparams.cpp
  purpose: Ensures private keys start with "5", "K", or "L"
  constraints: Base58 encoded

Parameter:
  name: ZCash Payment Address
  value: [0x16,0x9A]
  location: src/chainparams.cpp
  purpose: Guarantees addresses start with "zc"
  constraints: Base58 encoded
```

## Consensus Parameters
```yaml
Parameter:
  name: Proof of Work Limit
  value: 0007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  location: src/chainparams.cpp
  purpose: Maximum target for mining difficulty
  constraints: Must be below this value

Parameter:
  name: Block Time Target
  value: Pre-Blossom: 150 seconds, Post-Blossom: 75 seconds
  location: src/chainparams.cpp
  purpose: Target time between blocks
  constraints: Adjusted by difficulty algorithm

Parameter:
  name: Difficulty Adjustment Window
  value: 13 blocks
  location: src/chainparams.cpp
  purpose: Number of blocks for difficulty adjustment
  constraints: None

Parameter:
  name: Max Difficulty Adjustment Down
  value: 34%
  location: src/chainparams.cpp
  purpose: Maximum downward difficulty adjustment
  constraints: Per adjustment window

Parameter:
  name: Max Difficulty Adjustment Up
  value: 34%
  location: src/chainparams.cpp
  purpose: Maximum upward difficulty adjustment
  constraints: Per adjustment window
```

## Network Upgrades
```yaml
Parameter:
  name: Overwinter Activation
  value: Height 328500
  location: src/chainparams.cpp
  purpose: Network upgrade activation height
  constraints: Must activate at specified height

Parameter:
  name: Sapling Activation
  value: Height 328500
  location: src/chainparams.cpp
  purpose: Privacy features activation height
  constraints: Must activate at specified height
```

## Community Fee Parameters
```yaml
Parameter:
  name: Community Fee Start Height
  value: 328500
  location: src/chainparams.cpp
  purpose: Start of community fee distribution
  constraints: Must be above 0

Parameter:
  name: Community Fee End Height
  value: 1400000
  location: src/chainparams.cpp
  purpose: End of community fee distribution
  constraints: Must be above start height
```

## Future Block Time Windows
```yaml
Parameter:
  name: Block Time Windows
  values: |
    Height 0: 120 minutes
    Height 159300: 30 minutes
    Height 364400: 5 minutes
  location: src/chainparams.cpp
  purpose: Maximum future block time allowed
  constraints: Must be within specified window for height
```

## Genesis Block
```yaml
Parameter:
  name: Genesis Block Hash
  value: f499ee3d498b4298ac6a64205b8addb7c43197e2a660229be65db8a4534d75c1
  location: src/chainparams.cpp
  purpose: First block of the chain
  constraints: Must match exactly

Parameter:
  name: Genesis Block Time
  value: 1478403829
  location: src/chainparams.cpp
  purpose: Timestamp of first block
  constraints: Unix timestamp
