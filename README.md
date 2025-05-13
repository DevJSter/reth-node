## Initializing the db and stuff

```json
reth init --datadir "/Users/qoneqt/Desktop/shubham/rethnode/data" --chain config.json
```

## Running the node

```bash
reth node --datadir "/Users/qoneqt/Desktop/shubham/rethnode/data" --http --ws --port 30303 --http.api all --chain config.json
```
Add as many as v for more verbosity ggs


## Create the jwt token
```bash
header='{"alg":"HS256","typ":"JWT"}'
payload='{"iat": '$(date -u +%s)', "exp": '$(date -u -v +100y +%s)'}'
secret="a4460edff3b2d2624aa264a3187e06a8f2ce6d2b537918af8d1493c2fce3292e"

header_base64=$(echo -n "$header" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
payload_base64=$(echo -n "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
signature=$(echo -n "$header_base64.$payload_base64" | openssl dgst -sha256 -mac HMAC -macopt hexkey:$secret -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')

echo "$header_base64.$payload_base64.$signature"
```

## jwt token


```jwt_key
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOiAxNzQ3MDU0MTgzLCAiZXhwIjogNDkwMjcyNzc4M30.4cIrO3f4jRk6KhL1bPsvQ3Qu1JfQrL4wD2D2BJeWxWQ
```

## check if node is running or not 
```bash
curl -X POST http://localhost:8551 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOiAxNzQ3MDUwMjcxfQ.AZN-Qb1eQprecQPuJRsiCSnDYjVQmG1GLWDvaNdMBxw" \
  --data '{
    "jsonrpc":"2.0",
    "method":"eth_blockNumber",
    "params":[],
    "id":1
  }' 
```

## To get the chain id 

```bash
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' -H "Content-Type: application/json" localhost:8545
```

## To get the Eth parent hash 

```bash
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0", false],"id":1}' http://127.0.0.1:8545
```
