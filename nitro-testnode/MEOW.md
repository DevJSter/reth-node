# Nitro Testnode Quick Start

```bash
git clone -b release --recurse-submodules https://github.com/OffchainLabs/nitro-testnode.git
cd nitro-testnode
```

## Initialize and Run the Node

```bash
./test-node.bash --init
./test-node.bash
```

## Rollup Contract Addresses and Chain Configuration

You can obtain the rollup chain configuration, including core contract addresses:

```bash
docker exec nitro-testnode-sequencer-1 cat /config/l2_chain_info.json
```

List other configuration files:

```bash
docker exec nitro-testnode-sequencer-1 ls /config
```

## Token Bridge

Deploy an L1↔️L2 token bridge with `--tokenbridge`. After deployment, view contracts:

```bash
docker compose run --entrypoint sh tokenbridge -c "cat l1l2_network.json"
```

## Running an L3 Chain

Deploy an L3 chain on top of L2 with `--l3node`. Chain configuration:

```bash
docker exec nitro-testnode-sequencer-1 cat /config/l3_chain_info.json
```

Optional parameters:

- `--l3-fee-token`: Custom gas token for L3 (symbol `$APP`) deployed at `0x9b7c0fcc305ca36412f87fd6bd08c194909a7d4e`.
- `--l3-token-bridge`: Deploys an L2↔️L3 token bridge; view contracts:

```bash
docker compose run --entrypoint sh tokenbridge -c "cat l2l3_network.json"
```

## Additional Arguments

For a full list of options:

```bash
./test-node.bash --help
```

## Helper Scripts

Basic helper scripts for funding accounts and bridging funds:

```bash
./test-node.bash script --help
```

Example: fund an address on L2 (replace `<ADDRESS>`):

```bash
./test-node.bash script send-l2 \
  --to <ADDRESS> \
  --ethamount 500
```

## Blockscout Explorer

Enable local Blockscout with `--blockscout`:

```bash
./test-node.bash --blockscout
```

Access at: [http://localhost:4000](http://localhost:4000)

## Default Endpoints and Addresses

| Node        | Chain ID | RPC Endpoint                      |
|-------------|----------|-----------------------------------|
| L1 (geth)   | 1337     | http://localhost:8545             |
| L2 (nitro)  | 412346   | http://localhost:8547<br>ws://localhost:8548 |
| L3 (nitro)  | 333333   | http://localhost:3347             |



