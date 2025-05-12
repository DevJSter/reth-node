#!/bin/bash

# Configuration
NITRO_NODE_VERSION="v3.5.5-90ee45c"  # Only update this when you need a new version
DATADIR="./nitro-datadir"  # Local data directory
RPC=http://127.0.0.1:8547
PRIVATE_KEY=0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
CREATE2_FACTORY=0x4e59b44847b379578588920ca78fbf26c0b4956c
SALT=0x0000000000000000000000000000000000000000000000000000000000000000

# Check if the nitro repository is already cloned
if [ ! -d "./nitro" ]; then
    echo "Cloning Nitro repository..."
    git clone --branch $NITRO_NODE_VERSION https://github.com/OffchainLabs/nitro.git
    cd nitro
    git submodule update --init --recursive
    cd ..
fi

# Check if foundry tools (cast) are installed
if ! command -v cast &> /dev/null; then
    echo "Foundry tools not found. Please run setup-nitro.sh first."
    exit 1
fi

# Parse arguments
STYLUS_MODE="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stylus)
      STYLUS_MODE="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Build Nitro node if it doesn't exist
if [ ! -f "./nitro/target/bin/nitro" ]; then
    echo "Building Nitro node from source..."
    cd nitro
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        echo "Go is not installed. Please run setup-nitro.sh first."
        exit 1
    fi
    
    # Build Nitro node
    echo "Running make build..."
    make build
    cd ..
    
    if [ ! -f "./nitro/target/bin/nitro" ]; then
        echo "Failed to build Nitro node."
        exit 1
    fi
    
    echo "Nitro node built successfully!"
fi

# Create data directory if it doesn't exist
mkdir -p $DATADIR
mkdir -p ./preimages

# Start Nitro node in the background using config file if it exists
if [ -f "./config.json" ]; then
    echo "Starting Nitro node with config file..."
    ./nitro/target/bin/nitro --conf ./config.json --datadir $DATADIR &
else
    echo "Starting Nitro node in dev mode..."
    ./nitro/target/bin/nitro --dev --datadir $DATADIR --http.addr 0.0.0.0 --http.api=net,web3,eth,debug &
fi

NODE_PID=$!

# Kill background processes when exiting
trap 'kill $NODE_PID 2>/dev/null' EXIT

# Wait for the node to initialize
echo "Waiting for the Nitro node to initialize..."
until [[ "$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  $RPC)" == *"result"* ]]; do
    sleep 1
    echo "Still waiting for node to start..."
done

# Check if node is running
curl_output=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  $RPC)

if [[ "$curl_output" == *"result"* ]]; then
  echo "Nitro node is running!"
else
  echo "Failed to start Nitro node."
  exit 1
fi

# Make the caller a chain owner
echo "Setting chain owner to pre-funded dev account..."
cast send 0x00000000000000000000000000000000000000FF "becomeChainOwner()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC

# Set the L1 data fee to 0 so it doesn't impact the L2 Gas limit.
echo "Setting L1 price per unit to 0..."
cast send -r $RPC --private-key $PRIVATE_KEY 0x0000000000000000000000000000000000000070 'setL1PricePerUnit(uint256)' 0x0

# Deploy CREATE2 factory
echo "Deploying the CREATE2 factory..."
cast send --rpc-url $RPC --private-key $PRIVATE_KEY --value "1 ether" 0x3fab184622dc19b6109349b94811493bf2a45362
cast publish --rpc-url $RPC 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222

# Check CREATE2 factory deployment
if [ "$(cast code -r $RPC $CREATE2_FACTORY)" == "0x" ]; then
  echo "Failed to deploy CREATE2 factory"
  exit 1
fi
echo "CREATE2 factory deployed successfully"

# Deploy Cache Manager Contract
echo "Deploying Cache Manager contract..."
deploy_output=$(cast send --private-key $PRIVATE_KEY \
  --rpc-url $RPC \
  --create 0x60a06040523060805234801561001457600080fd5b50608051611d1c61003060003960006105260152611d1c6000f3fe)

# Extract contract address using awk from plain text output
contract_address=$(echo "$deploy_output" | awk '/contractAddress/ {print $2}')

# Check if contract deployment was successful
if [[ -z "$contract_address" ]]; then
  echo "Error: Failed to extract contract address. Full output:"
  echo "$deploy_output"
  exit 1
fi

echo "Cache Manager contract deployed at address: $contract_address"

# Register the deployed Cache Manager contract
echo "Registering Cache Manager contract as a WASM cache manager..."
registration_output=$(cast send --private-key $PRIVATE_KEY \
  --rpc-url $RPC \
  0x0000000000000000000000000000000000000070 \
  "addWasmCacheManager(address)" "$contract_address")

# Check if registration was successful
if [[ "$registration_output" == *"error"* ]]; then
  echo "Failed to register Cache Manager contract. Registration output:"
  echo "$registration_output"
  exit 1
fi
echo "Cache Manager deployed and registered successfully"

# Create stylus-deployer-bytecode.txt file if needed for Stylus mode
if [ ! -f "./stylus-deployer-bytecode.txt" ]; then
  echo "stylus-deployer-bytecode.txt not found. Creating a sample file..."
  echo "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80633d8b6ec41461003b578063fb0e4974146100be575b600080fd5b6100a8610049366046610112565b806000825b600a81101561008e5761007d6040518060600160405280602f81526020016100f1602f9139610125565b159150600101610051565b50806005036000557f5a04311af0b10a161dafd816a9c19b86c55ef5a24eed03a91587a328a74a6e6a81604051610087919061013b565b60405180910390a25050565b6100d16100cc366046610112565b90565b60405190815260200161008f565b634e487b7160e01e600052604160045260246000fd5b60006020828403121561012457600080fd5b5035919050565b60008151116002565b602081526000825180602084015261015a816040850160208701610125565b601f01601f1916919091016040019291505056fe" > stylus-deployer-bytecode.txt
fi

if [[ "$STYLUS_MODE" == "true" ]]; then
  # Deploy StylusDeployer
  echo "Deploying StylusDeployer..."
  deployer_code=$(cat ./stylus-deployer-bytecode.txt)
  deployer_address=$(cast create2 --salt $SALT --init-code $deployer_code)
  cast send --private-key $PRIVATE_KEY --rpc-url $RPC \
      $CREATE2_FACTORY "$SALT$deployer_code"
  if [ "$(cast code -r $RPC $deployer_address)" == "0x" ]; then
    echo "Failed to deploy StylusDeployer"
    exit 1
  fi
  echo "StylusDeployer deployed at address: $deployer_address"
fi

# If no errors, print success message
echo "Nitro node is running with data directory at $DATADIR"
echo "Use Ctrl+C to stop the node"
wait  # Keep the script alive and the node running