#curl -X POST -d "@testdata/example.cpp" https://10.1.6.16:8443/upload --cacert rte_keys/cert_ca.pem

TOE=$(base64 testdata/a.out -w 0)
#echo $TOE

curl -X POST -H "Content-Type: application/json" -d '{
  "toe": {
    "format": "string",
    "base64_encoded_toe": "'"$TOE"'"
  },
  "test_suite": [
    {
      "tool_name": "checksec",
      "parameters": null
    }
  ]
}' https://10.1.6.16:8443/upload --cacert cert_ca.pem
