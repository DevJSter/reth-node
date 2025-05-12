reth node --config reth-config.toml -vvvvv

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
