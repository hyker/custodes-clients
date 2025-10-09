base64 testdata/commons-collections-3.2.1.jar -w 0 | \
  jq -R '{toe: {format: "string", base64_encoded_toe: .}, test: {tool_name: "dependency-check", parameters: [{param_name: "--format=", value: "JSON"}]}}' | \
  curl -X POST -H "Content-Type: application/json" -d @- https://10.1.6.16:8443/upload --cacert cert_ca.pem
