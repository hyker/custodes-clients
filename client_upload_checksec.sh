#curl -X POST -d "@testdata/example.cpp" https://10.1.6.16:8443/upload --cacert rte_keys/cert_ca.pem

TOE=$(base64 testdata/a.out -w 0)
echo '{
  "toe": {
    "format": "string",
    "base64_encoded_toe": "'"$TOE"'"
  },
  "test": {
      "tool_name": "checksec",
      "parameters": null
  }
}' >payload.data

curl -X POST -H "Content-Type: application/json" -d @payload.data https://10.1.6.16:8443/upload --cacert cert_ca.pem

rm payload.data
