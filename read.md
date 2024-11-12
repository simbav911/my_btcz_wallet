# BitcoinZ Transaction Creation Guide
From copay wallet.

## Network Parameters
```javascript
{
  name: 'bitcoinz',
  alias: 'BTCZ',
  unit: 'BTCZ',
  networkMagic: 0x5A42, // BitcoinZ network magic
  pubKeyHash: 0x1CB8,   // Base58 address prefix
  scriptHash: 0x1CBD,   // P2SH address prefix
  wif: 0x80,           // WIF format prefix
  bip32: {
    public: 0x0488B21E,  // BIP32 public key prefix
    private: 0x0488ADE4  // BIP32 private key prefix
  },
  bip44: 177,          // BIP44 coin type
  dustThreshold: 1000,  // Minimum amount for valid transaction
  port: 1989,          // Default network port
  portRpc: 1979,       // Default RPC port
  protocol: {
    magic: 0x24e92764   // Protocol magic number
  }
}

## Transaction Structure
```javascript
{
  version: 4,            // Transaction version (4 for Overwinter/Sapling)
  versionGroupId: 0x892F2085, // Version group ID for BitcoinZ
  locktime: 0,          // Transaction locktime
  expiryHeight: 0,      // Block height when tx expires
  inputs: [{
    txid: string,       // Previous transaction ID (32 bytes)
    vout: number,       // Output index in previous tx
    sequence: number,   // Sequence number (usually 0xffffffff)
    script: string,     // ScriptSig for spending
    prevScriptPubKey: string // Script from previous output
  }],
  outputs: [{
    address: string,    // Recipient's address
    value: number,      // Amount in satoshis
    script: string      // ScriptPubKey for the output
  }]
}
```

## Creating a Transaction

1. **Gather Inputs**
```javascript
// Required fields for each input
{
  txid: '<previous_transaction_id>',
  vout: <output_index>,
  address: '<source_address>',
  scriptPubKey: '<previous_output_script>',
  amount: <amount_in_satoshis>,
  confirmations: <number_of_confirmations>
}
```

2. **Calculate Fees**
```javascript
// Fee calculation formula
const baseSize = 166;  // Base transaction size
const inputSize = 148; // Size per input
const outputSize = 34; // Size per output
const totalSize = baseSize + (inputSize * inputs.length) + (outputSize * outputs.length);
const feeRate = 10;    // Satoshis per byte
const fee = totalSize * feeRate;
```

3. **Create Raw Transaction**
```javascript
// Transaction format
const rawTransaction = {
  version: 4,
  versionGroupId: 0x892F2085,
  inputs: [{
    txid: '<input_transaction_id>',
    vout: <input_vout_number>,
    scriptSig: '', // Empty for unsigned
    sequence: 0xffffffff
  }],
  outputs: [{
    address: '<recipient_address>',
    value: <amount_in_satoshis>
  }],
  locktime: 0,
  expiryHeight: 0
};
```

4. **Sign Transaction**
```javascript
// Signing parameters
{
  hashType: 0x01,         // SIGHASH_ALL
  privateKey: '<private_key_wif>',
  publicKey: '<public_key_hex>',
  sigVersion: 0,          // SIGVERSION_BASE
  branchId: 0x76B809BB    // SAPLING_VERSION_GROUP_ID
}
```

5. **Broadcast Transaction**
```javascript
// RPC command
{
  method: 'sendrawtransaction',
  params: [
    '<signed_transaction_hex>',
    allowHighFees = false
  ]
}
```

## Network Validation Rules

1. **Transaction Size Limits**
- Maximum size: 2,000,000 bytes
- Maximum script size: 10,000 bytes
- Maximum number of sigops: 20,000

2. **Amount Validation**
- Minimum non-dust output: 1000 satoshis
- Maximum supply: 21,000,000,000 BTCZ
- Block reward: 12,500 BTCZ (halves every 840,000 blocks)

3. **Timing Rules**
- Block time: 2.5 minutes
- Difficulty adjustment: Every block
- Transaction expiry: 20 blocks (default)

4. **Script Standards**
- Supported types:
  * P2PKH (Pay to Public Key Hash)
  * P2SH (Pay to Script Hash)
  * P2PK (Pay to Public Key)
  * NULL_DATA (OP_RETURN)

5. **Signature Requirements**
- ECDSA signatures using secp256k1 curve
- DER-encoded signatures
- Maximum signature size: 72 bytes
- Required fields in signature:
  * r: 32 bytes
  * s: 32 bytes
  * hashtype: 1 byte

## Error Handling

1. **Common Error Codes**
```javascript
{
  -25: 'Missing inputs',
  -26: 'Transaction already in block chain',
  -27: 'Transaction already in mempool',
  -28: 'Invalid transaction format',
  -29: 'Insufficient funds',
  -30: 'Fee too low',
  -31: 'Bad script or signatures',
  -32: 'Transaction too large'
}
```

2. **Verification Steps**
- Check transaction format
- Verify input UTXOs exist
- Validate signature for each input
- Check output values are positive
- Ensure total output <= total input
- Verify transaction size and script limits
- Check against mempool conflicts
- Validate against consensus rules

## Example Transaction Creation

```javascript
// 1. Create transaction object
const tx = {
  version: 4,
  versionGroupId: 0x892F2085,
  inputs: [{
    txid: "abc123...", // Previous transaction ID
    vout: 0,          // Output index
    sequence: 0xffffffff
  }],
  outputs: [{
    address: "t1XYZ...", // Recipient address
    value: 1000000     // Amount in satoshis
  }],
  locktime: 0,
  expiryHeight: current_height + 20
};

// 2. Sign each input
for (let input of tx.inputs) {
  const signature = sign(tx, input, privateKey);
  input.scriptSig = createScriptSig(signature, publicKey);
}

// 3. Serialize transaction
const serializedTx = serialize(tx);

// 4. Broadcast
const txid = await rpc.sendrawtransaction(serializedTx);
```

## Testing Recommendations

1. **Before Broadcasting**
- Verify all amounts are correct
- Check fee calculation
- Validate signature for each input
- Ensure expiryHeight is appropriate
- Test transaction decode

2. **Network Testing**
- Use testnet first
- Verify with multiple nodes
- Check transaction propagation
- Monitor mempool acceptance

3. **Post-Broadcast**
- Monitor transaction status
- Check for replacements
- Verify confirmations
- Handle reorg scenarios
