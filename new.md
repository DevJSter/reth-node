# Arbitrum Nitro Local Testnet Setup

This guide shows how to run a **local Ethereum parent chain** (L1) with the latest Reth execution client and Lighthouse consensus client, then deploy a **local Arbitrum Nitro rollup (L2)** on top. We’ll run a custom Nitro sequencer and validator, and automate steps with bash scripts. The instructions use up-to-date releases (Reth v1.3.x, Nitro v3.6.x) and Docker for ease of setup.

## Prerequisites

* **Hardware/OS:** Linux (Ubuntu 22.04+) or Mac. Recommended ≥8GB RAM, 4 CPU cores.
* **Software:** [Docker](https://docs.docker.com/) (v20.10+), [Docker Compose](https://docs.docker.com/compose/), `bash`, `curl`.
* **Tools:** Optionally [Foundry’s `cast`](https://book.getfoundry.sh/quickstart/installation) or `hardhat` if you prefer deploying contracts manually. We’ll use Docker for most components.
* **Git Repos:** We’ll reference the official Reth and OffchainLabs Nitro repos for binaries and scripts.

## Folder Structure

Organize files into logical folders. For example:

```bash
project/
├── parent-chain/           # Ethereum L1 chain (Reth+Lighthouse)
│   ├── start_reth.sh       # Script to start Reth & Lighthouse
│   └── rethdata/           # Reth data directory (incl. jwt.hex)
├── rollup-chain/           # Arbitrum Nitro L2 chain
│   ├── start_sequencer.sh  # Script to run the Nitro sequencer
│   ├── start_validator.sh  # Script to run the Nitro validator
│   └── arbdata/            # Nitro node data dir
└── README.md               # This file
```

You can name and structure directories as desired; just adjust paths in scripts.

## 1. Run the Parent Ethereum Chain (Reth + Lighthouse)

We use Reth (execution client) and Lighthouse (consensus client) to simulate an Ethereum L1. For a quick local testnet, we use Reth’s built‑in “dev” chain (custom genesis) and Lighthouse in minimal mode.

1. **Generate JWT for EL/CL:** Both Reth and Lighthouse need a shared JWT for Engine API auth. Reth auto-generates `jwt.hex` in its data directory when started. For Docker, you can create one manually:

   ```bash
   mkdir -p parent-chain/rethdata
   openssl rand -hex 32 | tr -d '\n' > parent-chain/rethdata/jwt.hex
   ```
2. **Start Reth (Execution Layer):** Run Reth in Docker, exposing the JSON-RPC (8545) and Engine API (8551). For example:

   ```bash
   docker run -d --name reth \
     -v $(pwd)/parent-chain/rethdata:/root/.local/share/reth/dev \
     -p 8545:8545 -p 8551:8551 \
     ghcr.io/paradigmxyz/reth:latest reth node --chain dev \
       --http --http.addr 0.0.0.0 --http.api=eth,net,web3 \
       --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /root/.local/share/reth/dev/jwt.hex
   ```

   This starts Reth on the *dev* network. Reth’s Engine API (HTTP JSON-RPC) listens on port 8551 by default.
3. **Start Lighthouse (Consensus Layer):** Run Lighthouse and connect it to Reth’s Engine API:

   ```bash
   docker run -d --name lighthouse --network host sigp/lighthouse:latest \
     lighthouse bn \
       --network minimal \
       --execution-endpoint http://localhost:8551 \
       --execution-jwt /root/.local/share/reth/dev/jwt.hex
   ```

   Here `--network minimal` is a lightweight local testnet configuration. The key is pointing `--execution-endpoint` to Reth at `http://localhost:8551` and supplying the same JWT. This ensures Lighthouse syncs with Reth.
4. **Verify L1 Is Running:**

   * Check Reth’s JSON-RPC:

     ```bash
     curl -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' http://localhost:8545
     ```

     You should get a hex block number (e.g. `"0x0"` on a new chain).
   * Check Lighthouse logs: `docker logs -f lighthouse` should show it syncing headers and fork choice updates. Successful sync means L1 is operational.

> **Tip:** The [Reth docs](https://reth.rs/run/mainnet.html) show how to start Reth and Lighthouse and share a JWT. In practice, we use Docker for simplicity, but you could also install the binaries and run them directly using `reth node` and `lighthouse bn ...`.

## 2. Deploy the Arbitrum Nitro Rollup Chain

With L1 running, we now launch a local Arbitrum Nitro L2 chain. OffchainLabs provides the **nitro-testnode** scripts for a full local simulation. We’ll adapt these to use our Reth/Lighthouse L1.

1. **Clone the Nitro Testnode repo:**

   ```bash
   git clone -b release --recurse-submodules https://github.com/OffchainLabs/nitro-testnode.git
   cd nitro-testnode
   ```

   The `release` branch has the latest stable configs.
2. **Initialize the Rollup:** The testnode scripts can auto-deploy the core rollup contracts and start the sequencer/validator. Run:

   ```bash
   ./test-node.bash --init
   ```

   This does several things (per [Arbitrum docs](https://docs.arbitrum.io/run-arbitrum-node/run-local-full-chain-simulation)): it launches a local Geth (dev-mode), deploys the Nitro rollup contracts to L1, and starts a Nitro sequencer and validator. In our setup, replace the dev-geth L1 with our Reth/Lighthouse. If you **don’t** want to use nitro-testnode’s built-in L1, you can configure the Nitro node manually (see next step).
3. **Start Nitro Node with Custom L1:** Alternatively, run the Nitro node Docker image directly, pointing it to your Reth endpoint. For example:

   ```bash
   docker run -d --name arb-nitro \
     -v $(pwd)/arbdata:/home/user/.arbitrum \
     -p 8547:8547 -p 8548:8548 \
     offchainlabs/nitro-node:v3.6.2-5b41a2d \
     --parent-chain.connection.url=http://host.docker.internal:8545 \
     --parent-chain.blob-client.beacon-url=http://host.docker.internal:8551 \
     --chain.id 1337 \
     --init.latest=pruned --http.api=eth,net,web3 --http.addr=0.0.0.0
   ```

   * **Image:** use the latest Nitro image (v3.6.2) from Docker Hub.
   * **RPC URLs:** `--parent-chain.connection.url` points to our Reth RPC (port 8545); `--parent-chain.blob-client.beacon-url` to Lighthouse (port 8551).
   * **Chain ID:** use a unique L2 chain ID (we use `1337` here as an example).
     This tells Nitro to initialize a new L2 chain on our local L1. The Nitro node will deploy the necessary contracts on L1 and begin processing. See [Arbitrum docs](https://docs.arbitrum.io/run-arbitrum-node/run-full-node) for Docker examples.
4. **Save Chain Config:** After init, Nitro will write `l2_chain_info.json` in the `arbdata` volume. It contains the rollup’s core contract addresses and config. You can inspect it with:

   ```bash
   docker exec arb-nitro cat /home/user/.arbitrum/l2_chain_info.json
   ```

## 3. Run the Custom Sequencer

The Nitro node we started is also the sequencer by default in this single-node setup. If you want to run a separate sequencer process (e.g. in a multi-node testnet), start another Nitro instance with the `--sequencer` flag. For simplicity, we continue with the single Nitro node as both sequencer and execution node. Transactions submitted to `http://localhost:8547` will be picked up immediately by the sequencer and included in blocks.

## 4. Run the Validator

To enable validation, configure the Nitro node with staking flags. In most Nitro versions, the same node can act as a validator by enabling staking. For example:

```bash
docker run -d --name arb-validator \
  -v $(pwd)/arbdata:/home/user/.arbitrum \
  offchainlabs/nitro-node:v3.6.2-5b41a2d-validator \
  --parent-chain.connection.url=http://host.docker.internal:8545 \
  --chain.id 1337 \
  --node.staker.enable \
  --node.staker.strategy Watchtower \
  --node.staker.parent-chain-wallet.password "secure-password" \
  --node.bold.enable
```

* We use the `-validator` image tag which sets a special entrypoint for split validation servers.
* Key flags (per Arbitrum docs):

  * `--node.staker.enable`: turns on validation.
  * `--node.staker.strategy`: e.g. `Watchtower`, `Defensive`, etc. Here we use `Watchtower` (default).
  * `--node.staker.parent-chain-wallet.password`: refers to a password for a Nitro-created wallet (or use `--node.staker.parent-chain-wallet.private-key` with a raw key). This wallet must have funds on L1 to post bonds.
  * `--node.bold.enable`: enables BoLD mode if your chain uses BoLD (Arbitrum One/Nova).
    Ensure the validator’s L1 wallet is funded (e.g. from the dev chain’s faucet) and, if needed, added to the rollup’s validator allowlist. Check the logs: you should see lines like `running as validator ... strategy=Watchtower` and periodic “validation succeeded” messages.

## 5. Automation Scripts

You can script these steps for convenience. Example `bash` scripts (place in `scripts/` or root):

```bash
# scripts/start_parent_chain.sh
#!/usr/bin/env bash
set -e
# Start Reth + Lighthouse
docker run -d --name reth \
  -v $(pwd)/parent-chain/rethdata:/root/.local/share/reth/dev \
  -p 8545:8545 -p 8551:8551 \
  ghcr.io/paradigmxyz/reth:latest reth node --chain dev \
    --http --http.addr 0.0.0.0 --http.api eth,net,web3 \
    --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /root/.local/share/reth/dev/jwt.hex
docker run -d --name lighthouse --network host sigp/lighthouse:latest \
  lighthouse bn --network minimal \
    --execution-endpoint http://localhost:8551 \
    --execution-jwt /root/.local/share/reth/dev/jwt.hex
```

```bash
# scripts/start_rollup.sh
#!/usr/bin/env bash
set -e
# Start Nitro node (sequencer+validator) using our L1
docker run -d --name arb-nitro \
  -v $(pwd)/arbdata:/home/user/.arbitrum \
  -p 8547:8547 -p 8548:8548 \
  offchainlabs/nitro-node:v3.6.2-5b41a2d \
  --parent-chain.connection.url=http://localhost:8545 \
  --parent-chain.blob-client.beacon-url=http://localhost:8551 \
  --chain.id 1337 \
  --init.latest=pruned --http.api=eth,net,web3 --http.addr=0.0.0.0 \
  --node.staker.enable --node.staker.strategy Watchtower \
  --node.staker.parent-chain-wallet.password "secure-password" \
  --node.bold.enable
```

You may combine scripts or add flags (e.g. for separate sequencer/validator processes). Use `docker logs -f reth`, `docker logs -f arb-nitro` to monitor progress.

## Common Pitfalls

* **JWT Mismatch:** Ensure Reth and Lighthouse use the *same* JWT file.
* **Networking:** If Docker cannot reach `localhost` for L1 from L2 container, use `--network host` or `host.docker.internal`.
* **Correct Ports:** Match Docker `-p` ports with `--http.addr` flags. E.g. Nitro exposes its RPC on 8547/WS 8548 by default.
* **Data Persistence:** Use Docker volumes (`-v`) for persistent data. The Nitro container expects a writeable dir at `/home/user/.arbitrum`.
* **Chain IDs:** Pick unique IDs for L1 vs L2. In our dev setup both are 1337, but you could use separate values.
* **Validator Keys:** Create or import a Nitro wallet (`nitro account create`) and fund it on L1 if you run staking. The example above uses a password; adjust as needed.
* **Version Mismatch:** Use matching major versions. For example, Nitro v3.6.2 with the v3.6.x contracts suite. Using older/newer versions may cause incompatibilities.

## Verifying the Setup

* **L1 Checks:**

  * `curl http://localhost:8545` RPC should respond (e.g. `eth_blockNumber`).
  * Lighthouse logs should indicate sync (`"Imported block headers"` messages).

* **L2 Checks:**

  * The Nitro sequencer RPC (`http://localhost:8547`) should respond to JSON-RPC. E.g. `curl http://localhost:8547 -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'` returns `"0x539"` (1337).
  * Nitro logs should show block production.
  * Validator logs should include “validation succeeded” or “running as validator”.

* **Demo Transaction:** Use a wallet (e.g. via `cast` or Metamask pointed at [http://localhost:8547](http://localhost:8547)) to send a tx on L2. The sequencer should include it quickly; verify on-chain (e.g. `eth_getBalance` on L2).

## References

* Reth Execution Client documentation
* Lighthouse Consensus Client docs (Sigma Prime)
* Arbitrum Nitro node docs and examples
* OffchainLabs **nitro-testnode** repo (full local simulation)
* Nitro Core Contracts (for manual deployments) (see *canonical factory contracts* in Arbitrum docs if needed)

Feel free to adjust versions, ports, or use alternate installation methods. With these steps, you’ll have a fully local Arbitrum Nitro testnet with Reth/Lighthouse L1, and your own L2 sequencer and validator.
