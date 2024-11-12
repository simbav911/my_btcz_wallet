# BitcoinZ Network Protocol Specifications

## Connection Parameters
```yaml
Parameter:
  name: Default Port
  value: 1989 (mainnet), 11989 (testnet)
  location: src/net.h
  purpose: Network communication
  constraints: Must be open for incoming connections

Parameter:
  name: Max Peer Connections
  value: 125
  location: src/net.h
  purpose: Limit network connections
  constraints: Default maximum connections

Parameter:
  name: Max Message Length
  value: 2MB (2 * 1024 * 1024 bytes)
  location: src/net.h
  purpose: Protocol message size limit
  constraints: No message can exceed this size
```

## Network Timeouts
```yaml
Parameter:
  name: Ping Interval
  value: 120 seconds
  location: src/net.h
  purpose: Connection keepalive and latency measurement
  constraints: Regular interval for ping messages

Parameter:
  name: Connection Timeout
  value: 1200 seconds (20 minutes)
  location: src/net.h
  purpose: Disconnect unresponsive peers
  constraints: After waiting for ping response
```

## Protocol Messages
```yaml
Parameter:
  name: Maximum Inventory Size
  value: 50000 entries
  location: src/net.h
  purpose: Limit inventory message size
  constraints: Maximum items in 'inv' message

Parameter:
  name: Address Broadcast
  value: 1000 addresses
  location: src/net.h
  purpose: Peer address sharing
  constraints: Maximum new addresses to accumulate before announcing
```

## Error Codes
```yaml
Parameter:
  name: RPC Errors
  values: |
    - RPC_INVALID_REQUEST (-32600): Invalid request format
    - RPC_METHOD_NOT_FOUND (-32601): Method not found
    - RPC_INVALID_PARAMS (-32602): Invalid parameters
    - RPC_INTERNAL_ERROR (-32603): Internal error
    - RPC_PARSE_ERROR (-32700): Parse error
  location: src/rpc/protocol.h
  purpose: Standard JSON-RPC error reporting

Parameter:
  name: Wallet Errors
  values: |
    - RPC_WALLET_ERROR (-4): General wallet issues
    - RPC_WALLET_INSUFFICIENT_FUNDS (-6): Insufficient funds
    - RPC_WALLET_UNLOCK_NEEDED (-13): Wallet passphrase required
    - RPC_WALLET_PASSPHRASE_INCORRECT (-14): Incorrect passphrase
  location: src/rpc/protocol.h
  purpose: Wallet-specific error handling
```

## Network Communication
```yaml
Parameter:
  name: Connection Types
  values: |
    - Inbound: Connections initiated by peers
    - Outbound: Connections initiated locally
    - Manual: Explicitly requested connections
  location: src/net.h
  purpose: Peer connection management

Parameter:
  name: Handshake Process
  steps: |
    1. Version message exchange
    2. Verack message confirmation
    3. Service bit verification
    4. Protocol version compatibility check
  location: src/net.h
  purpose: Establish peer connections
```

## Peer Management
```yaml
Parameter:
  name: Ban Duration
  value: 86400 seconds (24 hours)
  location: src/net.h
  purpose: Default ban time for misbehaving peers
  constraints: Can be modified via RPC

Parameter:
  name: Node Scoring
  rules: |
    - Track peer behavior
    - Ban for protocol violations
    - Whitelist trusted peers
    - Maintain connection quality metrics
  location: src/net.h
  purpose: Network health maintenance
```

## Data Synchronization
```yaml
Parameter:
  name: Block Sync
  process: |
    1. Request headers
    2. Validate headers
    3. Request blocks
    4. Verify blocks
  location: src/net.h
  purpose: Blockchain synchronization

Parameter:
  name: Transaction Relay
  rules: |
    1. Inventory announcement
    2. Transaction request
    3. Transaction verification
    4. Relay to other peers
  location: src/net.h
  purpose: Transaction propagation
```

## Network Upgrade Protocol
```yaml
Parameter:
  name: Upgrade Preference Period
  value: 24 * 24 * 3 blocks
  location: src/net.h
  purpose: Prefer connections to upgrading peers
  constraints: Active before network upgrades
```

## Error Recovery Procedures
```yaml
Parameter:
  name: Recovery Actions
  procedures: |
    1. Connection Failures:
       - Retry with exponential backoff
       - Try alternative peers
       - Check network connectivity

    2. Sync Failures:
       - Revert to last known good state
       - Re-request from different peer
       - Validate blockchain integrity

    3. Ban Recovery:
       - Wait for ban expiration
       - Clear ban via RPC if needed
       - Verify corrected behavior

    4. Network Split Recovery:
       - Detect chain splits
       - Compare work with peers
       - Reorganize to best chain
  location: src/net.h
  purpose: Handle network issues
