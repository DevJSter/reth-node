#!/bin/bash

# Clean up any existing processes
echo "Cleaning up existing processes..."
lsof -ti:8545 | xargs kill -9 2>/dev/null || true
lsof -ti:8546 | xargs kill -9 2>/dev/null || true

# Node 1 (Main node) - Start without --dev for better networking
echo "Starting Node 1..."
# Node 1 - Add mining account
reth node \
  --datadir "./data" \
  --chain "genesis.json" \
  --http \
  --http.api eth,net,web3,txpool,debug,admin \
  --port 30303 \
  --http.port 8545 \
  --authrpc.port 8551 \
  --miner.etherbase 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  -vvv &
NODE1_PID=$!

echo "Node 1 PID: $NODE1_PID"
echo "Waiting for Node 1 to fully start..."

# Wait for Node 1 to start and be ready
sleep 15

# Check if Node 1 is responding
echo "Checking if Node 1 is ready..."
for i in {1..10}; do
    if curl -s http://localhost:8545 > /dev/null 2>&1; then
        echo "Node 1 is ready!"
        break
    fi
    echo "Waiting for Node 1... (attempt $i/10)"
    sleep 3
done

# Get enode from Node 1
echo "Getting enode from Node 1..."
ENODE=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' | \
  jq -r '.result.enode' 2>/dev/null)

if [ -z "$ENODE" ] || [ "$ENODE" = "null" ]; then
    echo "Failed to get enode from Node 1. Exiting..."
    kill $NODE1_PID 2>/dev/null || true
    exit 1
fi

echo "Node 1 enode: $ENODE"

# Node 2 (Secondary node) - Also use --dev but try to connect
echo "Starting Node 2 with bootnode..."
reth node \
  --datadir "./data-node2" \
  --chain "genesis.json" \
  --http \
  --http.api eth,net,web3,txpool,debug,admin \
  --port 30304 \
  --http.port 8546 \
  --authrpc.port 8552 \
  --dev \
  --dev.block-time 15s \
  --bootnodes "$ENODE" \
  -vvv &
NODE2_PID=$!

echo "Node 2 PID: $NODE2_PID"

# Wait a bit for Node 2 to start
sleep 10

# Try to manually connect them as well
echo "Manually connecting nodes..."
curl -s -X POST -H "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE\"],\"id\":1}" \
  http://localhost:8546

echo ""
echo "=== Connection Status ==="
echo "Node 1 HTTP: http://localhost:8545"
echo "Node 2 HTTP: http://localhost:8546"
echo ""
echo "Checking peer connections..."
sleep 3

# Check peer counts
echo "Node 1 peer count:"
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545

echo -e "\nNode 2 peer count:"
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8546

echo -e "\n\nBoth nodes are running. Use Ctrl+C to stop both nodes."

# Function to handle cleanup on script exit
cleanup() {
    echo "Stopping nodes..."
    kill $NODE1_PID $NODE2_PID 2>/dev/null || true
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Wait for both nodes
wait $NODE1_PID $NODE2_PID