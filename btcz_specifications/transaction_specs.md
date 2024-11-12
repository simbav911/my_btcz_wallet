# BitcoinZ Transaction Specifications

## Transaction Versions
```yaml
Parameter:
  name: Sprout Version Range
  value: 1-2
  location: src/primitives/transaction.h
  purpose: Basic transaction format
  constraints: Must be within range

Parameter:
  name: Overwinter Version
  value: 3
  location: src/primitives/transaction.h
  purpose: Overwinter network upgrade
  constraints: Must match version group ID

Parameter:
  name: Sapling Version
  value: 4
  location: src/primitives/transaction.h
  purpose: Sapling network upgrade
  constraints: Must match version group ID
```

## Version Group IDs
```yaml
Parameter:
  name: Overwinter Group ID
  value: 0x03C48270
  location: src/primitives/transaction.h
  purpose: Identifies Overwinter transaction format
  constraints: Must be non-zero

Parameter:
  name: Sapling Group ID
  value: 0x892F2085
  location: src/primitives/transaction.h
  purpose: Identifies Sapling transaction format
  constraints: Must be non-zero
```

## Transaction Input Structure
```yaml
Parameter:
  name: CTxIn
  structure: |
    - prevout: COutPoint
      - hash: uint256 (previous tx hash)
      - n: uint32_t (output index)
    - scriptSig: CScript (unlocking script)
    - nSequence: uint32_t (sequence number)
  location: src/primitives/transaction.h
  purpose: Defines transaction inputs
```

## Transaction Output Structure
```yaml
Parameter:
  name: CTxOut
  structure: |
    - nValue: CAmount (value in zatoshis)
    - scriptPubKey: CScript (locking script)
  location: src/primitives/transaction.h
  purpose: Defines transaction outputs
```

## Shielded Components

### Spend Description
```yaml
Parameter:
  name: SpendDescription
  structure: |
    - cv: uint256 (value commitment)
    - anchor: uint256 (merkle root)
    - nullifier: uint256 (spend nullifier)
    - rk: uint256 (randomized key)
    - zkproof: GrothProof (zero-knowledge proof)
    - spendAuthSig: [64]byte (spend authorization)
  location: src/primitives/transaction.h
  purpose: Shielded spend parameters
  size: 384 bytes
```

### Output Description
```yaml
Parameter:
  name: OutputDescription
  structure: |
    - cv: uint256 (value commitment)
    - cmu: uint256 (note commitment)
    - ephemeralKey: uint256 (ephemeral public key)
    - encCiphertext: SaplingEncCiphertext
    - outCiphertext: SaplingOutCiphertext
    - zkproof: GrothProof (zero-knowledge proof)
  location: src/primitives/transaction.h
  purpose: Shielded output parameters
  size: 948 bytes
```

### JoinSplit Description
```yaml
Parameter:
  name: JSDescription
  structure: |
    - vpub_old: CAmount (public value entering shielded pool)
    - vpub_new: CAmount (public value exiting shielded pool)
    - anchor: uint256 (merkle root)
    - nullifiers: [2]uint256 (nullifiers array)
    - commitments: [2]uint256 (commitments array)
    - ephemeralKey: uint256
    - randomSeed: uint256
    - macs: [2]uint256 (message authentication codes)
    - proof: SproutProof
    - ciphertexts: [2]ZCNoteEncryption::Ciphertext
  location: src/primitives/transaction.h
  purpose: JoinSplit parameters
  size: |
    Sapling: 1698 bytes
    Pre-Sapling: 1802 bytes
```

## Transaction Structure
```yaml
Parameter:
  name: CTransaction
  structure: |
    - fOverwintered: bool
    - nVersion: int32_t
    - nVersionGroupId: uint32_t (if overwintered)
    - vin: vector<CTxIn>
    - vout: vector<CTxOut>
    - nLockTime: uint32_t
    - nExpiryHeight: uint32_t (if overwintered)
    - valueBalance: CAmount (if Sapling)
    - vShieldedSpend: vector<SpendDescription> (if Sapling)
    - vShieldedOutput: vector<OutputDescription> (if Sapling)
    - vJoinSplit: vector<JSDescription> (if version >= 2)
    - joinSplitPubKey: uint256 (if has JoinSplits)
    - joinSplitSig: [64]byte (if has JoinSplits)
    - bindingSig: [64]byte (if has Sapling data)
  location: src/primitives/transaction.h
  purpose: Complete transaction format
```

## Signature Hash Types
```yaml
Parameter:
  name: Signature Types
  values: |
    - Standard Bitcoin-style signatures for transparent inputs
    - Spend authorization signatures for shielded spends
    - JoinSplit signatures for JoinSplit descriptions
    - Binding signatures for Sapling value balance
  location: src/primitives/transaction.h
  purpose: Transaction authorization
```

## Transaction Validation Rules
```yaml
Parameter:
  name: Validation Rules
  rules: |
    1. Version must match network upgrade state
    2. Version group ID must match if overwintered
    3. Transaction must not be expired (nExpiryHeight)
    4. Value balance must be valid for shielded components
    5. All signatures must be valid
    6. All proofs must be valid
    7. Nullifiers must not be previously spent
    8. Value range checks for all components
  location: src/primitives/transaction.h
  purpose: Ensure transaction validity
