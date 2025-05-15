#curl -X POST -d "@testdata/example.cpp" https://10.1.6.16:8443/upload --cacert rte_keys/cert_ca.pem

TOE=$(base64 testdata/example.cpp)

curl -X POST -H "Content-Type: application/json" -d '{
  "toe": {
    "format": "string",
    "base64_encoded_toe": "'"$TOE"'"
  },
  "test": {
      "tool_name": "cppcheck",
      "parameters": null
   } 
}' https://10.1.6.16:8443/upload --cacert cert_ca.pem
