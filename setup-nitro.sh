#!/bin/bash

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install dependencies
echo "Installing dependencies..."
brew install go curl git jq cmake pkg-config openssl autoconf automake libtool

# Make sure CMake is at least version 3.5
CMAKE_VERSION=$(cmake --version | head -n1 | awk '{print $3}')
if [ "$(echo "$CMAKE_VERSION" | awk -F. '{print $1*10000+$2*100+$3}')" -lt 30500 ]; then
    echo "CMake version $CMAKE_VERSION is too old, upgrading..."
    brew upgrade cmake
fi

# Install Foundry tools for Ethereum development
echo "Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc 2>/dev/null || source ~/.bash_profile 2>/dev/null || source ~/.zshrc 2>/dev/null
~/.foundry/bin/foundryup

# Add Foundry to PATH for this session
export PATH="$HOME/.foundry/bin:$PATH"

# Configure Go environment
echo "Configuring Go environment..."
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Clone nitro repository if it doesn't exist
if [ ! -d "./nitro" ]; then
    echo "Cloning Nitro repository..."
    git clone https://github.com/OffchainLabs/nitro.git
    cd nitro
    git checkout v3.5.5 # Use the main version tag
    # The exact hash from your Docker script is 90ee45c
    git submodule update --init --recursive
    cd ..
fi

# Check if config.json exists
if [ ! -f "./config.json" ]; then
    echo "Creating config.json file..."
    cat > config.json << 'EOL'
{
   "chain": {
     "id": 42161000,
     "name": "MyArbitrumChain"
   },
   "http": {
     "addr": "0.0.0.0",
     "port": 8547,
     "api": ["net", "web3", "eth", "debug", "arb"]
   },
   "execution": {
     "sequencer": {
       "enable": true,
       "dangerous": {
         "no-coordinator": true
       }
     }
   },
   "init": {
     "preimagedir": "./preimages"
   },
   "parent-chain": {
     "connection": {
       "url": "http://localhost:8545"
     }
   }
}
EOL
    echo "Created default config.json"
else
    echo "config.json already exists, keeping your current file"
fi

# Install Rust and tools for Stylus support
echo "Would you like to install Rust and Stylus support? (y/n)"
read -r install_stylus

if [[ "$install_stylus" == "y" || "$install_stylus" == "Y" ]]; then
    # Install Rust if not already installed
    if ! command -v rustup &> /dev/null; then
        echo "Installing Rust toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.81.0
        source "$HOME/.cargo/env"
    fi

    # Add WASM targets for Stylus development
    echo "Adding WASM targets..."
    rustup target add wasm32-unknown-unknown
    
    # Check if we're on Apple Silicon (arm64)
    if [[ $(uname -m) == "arm64" ]]; then
        echo "Detected Apple Silicon (ARM64), using wasm32-wasip1 target"
        rustup target add wasm32-wasip1
    else
        echo "Using wasm32-wasi target"
        rustup target add wasm32-wasi
    fi

    # Install cargo-stylus
    echo "Installing cargo-stylus..."
    cargo install --force cargo-stylus
    
    echo "Stylus support has been installed"
fi

# Build the Nitro node
echo "Building Nitro node from source..."
cd nitro

# Fix CMake version issue in brotli
BROTLI_CMAKE_FILE="third_party/brotli/CMakeLists.txt"
if [ -f "$BROTLI_CMAKE_FILE" ]; then
    echo "Fixing CMake version requirement in Brotli..."
    sed -i.bak 's/cmake_minimum_required(VERSION 2.8.12)/cmake_minimum_required(VERSION 3.5)/' "$BROTLI_CMAKE_FILE"
fi

make build
cd ..

# Create the required directories
mkdir -p ./nitro-datadir
mkdir -p ./preimages

# Create an empty stylus-deployer-bytecode.txt file for Stylus mode
if [ ! -f "./stylus-deployer-bytecode.txt" ]; then
    echo "Creating stylus-deployer-bytecode.txt file..."
    echo "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80633d8b6ec41461003b578063fb0e4974146100be575b600080fd5b6100a8610049366046610112565b806000825b600a81101561008e5761007d6040518060600160405280602f81526020016100f1602f9139610125565b159150600101610051565b50806005036000557f5a04311af0b10a161dafd816a9c19b86c55ef5a24eed03a91587a328a74a6e6a81604051610087919061013b565b60405180910390a25050565b6100d16100cc366046610112565b90565b60405190815260200161008f565b634e487b7160e01e600052604160045260246000fd5b60006020828403121561012457600080fd5b5035919050565b60008151116002565b602081526000825180602084015261015a816040850160208701610125565b601f01601f1916919091016040019291505056fe" > stylus-deployer-bytecode.txt
fi

# Verify the build
if [ -f "./nitro/target/bin/nitro" ]; then
    echo "Nitro node built successfully!"
else
    echo "Failed to build Nitro node. Please check the logs above for errors."
    exit 1
fi

echo ""
echo "Setup complete! Next steps:"
echo "1. Review the config.json file if you want to customize your Nitro node"
echo "2. Run ./run-nitro.sh to start your local Nitro node"
echo "3. Run ./run-nitro.sh --stylus to start with Stylus support"