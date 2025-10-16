#!/bin/bash
# Test script to verify that dependency-check requests without --file-type are rejected

echo "Testing dependency-check request WITHOUT --file-type parameter..."
echo "This should be rejected by the server."
echo ""

base64 testdata/commons-collections-3.2.1.jar -w 0 | \
  jq -R '{toe: {format: "string", base64_encoded_toe: .}, test: {tool_name: "dependency-check", parameters: [{param_name: "--format=", value: "JSON"}]}}' | \
  curl -X POST -H "Content-Type: application/json" -d @- https://localhost:8443/upload -k

echo ""
echo ""
echo "Expected result: Server should reject this request because --file-type is mandatory"
