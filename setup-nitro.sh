#!/bin/bash

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install dependencies
echo "Installing dependencies..."
brew install curl coreutils openssl pkg-config

# Install Foundry tools for Ethereum development
echo "Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc 2>/dev/null || source ~/.bash_profile 2>/dev/null || source ~/.zshrc 2>/dev/null
~/.foundry/bin/foundryup

# Install Rust if not already installed
if ! command -v rustup &> /dev/null; then
    echo "Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.81.0
    source "$HOME/.cargo/env"
fi

# Add WASM targets for Stylus development
rustup target add wasm32-unknown-unknown wasm32-wasi

# Install cargo-stylus
echo "Installing cargo-stylus..."
cargo install --force cargo-stylus

echo "Setup complete! You can now run ./run-nitro-local-macos.sh to start your local Nitro node."