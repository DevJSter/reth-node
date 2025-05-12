reth node --config reth-config.toml

```bash
header='{"alg":"HS256","typ":"JWT"}'
payload='{"iat": '$(date +%s)'}'
secret="a4460edff3b2d2624aa264a3187e06a8f2ce6d2b537918af8d1493c2fce3292e"

header_base64=$(echo -n "$header" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
payload_base64=$(echo -n "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
signature=$(echo -n "$header_base64.$payload_base64" | openssl dgst -sha256 -mac HMAC -macopt hexkey:$secret -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')

echo "$header_base64.$payload_base64.$signature"
```

```jwt_key
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOiAxNzQ3MDQ5OTY3fQ.Syf6NB_zCRSYSu3LKE3hmpRLA3bAQLxbHrxRHDuQPwU
```

```bash
curl -X POST http://localhost:8551 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOiAxNzQ3MDQ5OTY3fQ.Syf6NB_zCRSYSu3LKE3hmpRLA3bAQLxbHrxRHDuQPwU" \
  --data '{
    "jsonrpc":"2.0",
    "method":"eth_blockNumber",
    "params":[],
    "id":1
  }'
```
