Ah, I see! You want to set up a reth node for the L2 (Arbitrum) just like your L1 setup, and then add Lighthouse as the consensus client. Let's do this step by step on macOS.

## Setting up Lighthouse for your L1 (First Priority)

Since your L1 reth is already running, let's add Lighthouse as the consensus client for it:

### 1. Install Lighthouse

```bash
# Using Homebrew
brew tap sigp/lighthouse
brew install lighthouse

# Or download directly from GitHub
# Visit: https://github.com/sigp/lighthouse/releases
# Download the macOS binary
```

### 2. Create JWT secret file for Lighthouse

Since you already have a JWT token, save it to a file:

```bash
echo -n "a4460edff3b2d2624aa264a3187e06a8f2ce6d2b537918af8d1493c2fce3292e" > /Users/qoneqt/Desktop/shubham/rethnode/jwt.hex
```

### 3. Initialize Lighthouse for your custom network

Create a directory for Lighthouse:

```bash
mkdir -p /Users/qoneqt/Desktop/shubham/lighthouse
cd /Users/qoneqt/Desktop/shubham/lighthouse
```

### 4. Create custom network config for Lighthouse

Create a `config.yaml` file for your custom network:

```yaml
# /Users/qoneqt/Desktop/shubham/lighthouse/config.yaml
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: 1
MIN_GENESIS_TIME: 0
GENESIS_FORK_VERSION: 0x00000000
GENESIS_DELAY: 0

# Altair
ALTAIR_FORK_VERSION: 0x01000000
ALTAIR_FORK_EPOCH: 0

# Bellatrix (Merge)
BELLATRIX_FORK_VERSION: 0x02000000
BELLATRIX_FORK_EPOCH: 0
TERMINAL_TOTAL_DIFFICULTY: 1

# Capella
CAPELLA_FORK_VERSION: 0x03000000
CAPELLA_FORK_EPOCH: 0

# Deneb
DENEB_FORK_VERSION: 0x04000000
DENEB_FORK_EPOCH: 0

# Time parameters
SECONDS_PER_SLOT: 12
SLOTS_PER_EPOCH: 32

# Deposit contract
DEPOSIT_CHAIN_ID: 12345
DEPOSIT_NETWORK_ID: 12345
DEPOSIT_CONTRACT_ADDRESS: 0x0000000000000000000000000000000000000000

# Network
PRESET_BASE: mainnet
CONFIG_NAME: custom-network
```

### 5. Create genesis state for Lighthouse

Create a `genesis.ssz` file (you'll need to generate this based on your network):

```bash
# Create a minimal genesis state
lighthouse \
    --datadir /Users/qoneqt/Desktop/shubham/lighthouse/data \
    beacon_node \
    --testnet-dir /Users/qoneqt/Desktop/shubham/lighthouse \
    genesis \
    --eth1-endpoint http://localhost:8545
```

### 6. Run Lighthouse beacon node

```bash
lighthouse beacon_node \
    --datadir /Users/qoneqt/Desktop/shubham/lighthouse/data \
    --network custom \
    --execution-endpoint http://localhost:8551 \
    --execution-jwt /Users/qoneqt/Desktop/shubham/rethnode/jwt.hex \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5054 \
    --checkpoint-sync-url-timeout 300 \
    --testnet-dir /Users/qoneqt/Desktop/shubham/lighthouse
```

### 7. Run Lighthouse validator client (if needed)

```bash
lighthouse validator_client \
    --datadir /Users/qoneqt/Desktop/shubham/lighthouse/data \
    --beacon-nodes http://localhost:5052 \
    --network custom \
    --testnet-dir /Users/qoneqt/Desktop/shubham/lighthouse
```

## Setting up Reth for L2 (Arbitrum)

Now let's set up reth for the L2:

### 1. Create L2 directory structure

```bash
mkdir -p /Users/qoneqt/Desktop/shubham/reth-l2/data
cd /Users/qoneqt/Desktop/shubham/reth-l2
```

### 2. Create L2 genesis config

Create `config-l2.json`:

```json
{
  "config": {
    "chainId": 412345,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "mergeForkBlock": 0,
    "arbitrum": {
      "EnableArbOS": true,
      "AllowDebugPrecompiles": true
    }
  },
  "nonce": "0x0",
  "timestamp": "0x0",
  "extraData": "0xarbitrum",
  "gasLimit": "0x7A1200",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "0xE2b39f4cfFA5B17434e47Ab5F54b984155e4b7aD": {
      "balance": "0x8AC7230489E80000"
    }
  }
}
```

### 3. Initialize L2 reth

```bash
reth init --datadir "/Users/qoneqt/Desktop/shubham/reth-l2/data" --chain config-l2.json
```

### 4. Create L2 JWT token

```bash
# Create a new secret for L2
l2_secret="b5560edff3b2d2624aa264a3187e06a8f2ce6d2b537918af8d1493c2fce3292f"

# Save it
echo -n "$l2_secret" > /Users/qoneqt/Desktop/shubham/reth-l2/jwt.hex

# Generate JWT token with the new secret
header='{"alg":"HS256","typ":"JWT"}'
payload='{"iat": '$(date -u +%s)', "exp": '$(date -u -v +100y +%s)'}'

header_base64=$(echo -n "$header" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
payload_base64=$(echo -n "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
signature=$(echo -n "$header_base64.$payload_base64" | openssl dgst -sha256 -mac HMAC -macopt hexkey:$l2_secret -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')

echo "L2 JWT: $header_base64.$payload_base64.$signature"
```

### 5. Run L2 reth node

```bash
reth node \
    --datadir "/Users/qoneqt/Desktop/shubham/reth-l2/data" \
    --http \
    --ws \
    --port 30304 \
    --http.port 8547 \
    --ws.port 8548 \
    --authrpc.port 8552 \
    --metrics 9002 \
    --http.api all \
    --chain config-l2.json \
    --authrpc.jwtsecret /Users/qoneqt/Desktop/shubham/reth-l2/jwt.hex
```

## Setting up Lighthouse for L2

### 1. Create L2 Lighthouse directory

```bash
mkdir -p /Users/qoneqt/Desktop/shubham/lighthouse-l2
cd /Users/qoneqt/Desktop/shubham/lighthouse-l2
```

### 2. Create L2 network config

Create `config-l2.yaml`:

```yaml
# /Users/qoneqt/Desktop/shubham/lighthouse-l2/config.yaml
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: 1
MIN_GENESIS_TIME: 0
GENESIS_FORK_VERSION: 0x00000001
GENESIS_DELAY: 0

# Fork versions for L2
ALTAIR_FORK_VERSION: 0x01000001
ALTAIR_FORK_EPOCH: 0
BELLATRIX_FORK_VERSION: 0x02000001
BELLATRIX_FORK_EPOCH: 0
CAPELLA_FORK_VERSION: 0x03000001
CAPELLA_FORK_EPOCH: 0
DENEB_FORK_VERSION: 0x04000001
DENEB_FORK_EPOCH: 0

# Time parameters
SECONDS_PER_SLOT: 2
SLOTS_PER_EPOCH: 16

# Deposit contract (different for L2)
DEPOSIT_CHAIN_ID: 412345
DEPOSIT_NETWORK_ID: 412345
DEPOSIT_CONTRACT_ADDRESS: 0x0000000000000000000000000000000000000001

# Network
PRESET_BASE: mainnet
CONFIG_NAME: custom-l2-network
```

### 3. Run L2 Lighthouse

```bash
lighthouse beacon_node \
    --datadir /Users/qoneqt/Desktop/shubham/lighthouse-l2/data \
    --network custom \
    --execution-endpoint http://localhost:8552 \
    --execution-jwt /Users/qoneqt/Desktop/shubham/reth-l2/jwt.hex \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5053 \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5055 \
    --testnet-dir /Users/qoneqt/Desktop/shubham/lighthouse-l2 \
    --target-peers 0
```

## Summary of Ports

- **L1 Reth**: 
  - HTTP: 8545
  - WS: 8546
  - Auth: 8551
  - P2P: 30303

- **L1 Lighthouse**:
  - HTTP: 5052
  - Metrics: 5054

- **L2 Reth**:
  - HTTP: 8547
  - WS: 8548
  - Auth: 8552
  - P2P: 30304

- **L2 Lighthouse**:
  - HTTP: 5053
  - Metrics: 5055

## Verification Commands

```bash
# Check L1 
curl http://localhost:8545/eth/v1/node/version

# Check L1 Lighthouse
curl http://localhost:5052/eth/v1/node/version

# Check L2
curl http://localhost:8547/eth/v1/node/version

# Check L2 Lighthouse
curl http://localhost:5053/eth/v1/node/version
```

This setup gives you complete control over both L1 and L2 with reth nodes and Lighthouse consensus clients. The L2 is configured to be Arbitrum-like but runs independently.