lsof -ti:8545 | xargs kill -9

rm -rf "/Users/qoneqt/Desktop/shubham/rethnode/POA/data" // just type the location of L! data 
reth init --datadir "/Users/qoneqt/Desktop/shubham/rethnode/POA/data" --chain genesis.json

reth node \
  --datadir "/Users/qoneqt/Desktop/shubham/rethnode/POA/data" \
  --chain genesis.json \
  --http \
  --http.api eth,net,web3,txpool,debug,admin \
  --ws \
  --port 30303 \
  --dev \
  --dev.block-time 15s \
  -vvvv