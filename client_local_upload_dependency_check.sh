base64 testdata/commons-collections-3.2.1.jar -w 0 | \
  jq -R '{toe: {format: "string", base64_encoded_toe: .}, test: {tool_name: "dependency-check", parameters: [{param_name: "--format=", value: "JSON"}, {param_name: "--file-type=", value: "jar"}]}}' | \
  curl -X POST -H "Content-Type: application/json" -d @- https://localhost:8443/upload -k
