#curl -X POST -d "@testdata/example.cpp" https://10.1.6.16:8443/upload --cacert rte_keys/cert_ca.pem

read -p "input request identifyer:" ID

curl -X POST -H "Content-Type: application/json" -d '{
  "identifier" : "'"$ID"'"
}' https://localhost:9000/result -k

# "identifier":
