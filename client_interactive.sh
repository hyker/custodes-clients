#!/bin/bash

set -e

LOCAL=false
# LOCAL=true

if $LOCAL; then
  SERVER_URL="https://localhost:9000"
else
  SERVER_URL="https://10.1.6.16:8443"
fi

CERT_PATH="cert_ca.pem"
CONFIG_FILE="security_test_config.json"
PUBLIC_KEY_FILE="key_rte_ssl_pub.pem"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print steps
print_step() {
  echo -e "${GREEN}[Step $1]${NC} $2"
}

# Function to print info
print_info() {
  echo -e "${BLUE}[Info]${NC} $1"
}

# Function to print warning
print_warning() {
  echo -e "${YELLOW}[Warning]${NC} $1"
}

# check if certificate exists
check_certificate() {
  if [[ ! -f "$CERT_PATH" ]]; then
    print_warning "Certificate file $CERT_PATH not found!"
    read -p "Enter path to certificate file: " new_cert_path
    if [[ -f "$new_cert_path" ]]; then
      CERT_PATH="$new_cert_path"
      print_info "Using certificate: $CERT_PATH"
    else
      print_warning "Certificate file $new_cert_path not found. Exiting."
      exit 1
    fi
  fi
}

# Function to get server quote (attestation)
verify_server() {
  print_step "1" "Verifying server security (getting quote)"

  if $LOCAL; then
    # quote_response=$(curl -s -X POST "$SERVER_URL/quote" -k)
    quote_response='{"quote_data": "LOCAL_DEBUG_NO_QUOTE"}'
  else
    quote_response=$(curl -s -X POST "$SERVER_URL/quote" --cacert "$CERT_PATH")
  fi

  # Check if the response is valid JSON
  if ! echo "$quote_response" | jq . &>/dev/null; then
    print_warning "Failed to get quote or invalid response."
    echo "Raw response: $quote_response"
    return 1
  fi

  print_info "Server quote received successfully"

  # Check if the response is valid JSON
  if ! echo "$quote_response" | jq . &>/dev/null; then
    print_warning "Failed to get quoteor invalid response. Server may be down."
    echo "Raw response: $quote_response"
    exit 1
  fi

  # Extract quote
  quote_data=$(echo "$quote_response" | jq -r '.quote_data')

  print_info "Base64 encoded quote data from RTE:\n$quote_data"

  read -p "Send quote to local verification service (requires local deployment of https://github.com/intel/SGX-TDX-DCAP-QuoteVerificationService)? (y/n): " automated_verification
  if [[ "$automated_verification" == "y" || "$automated_verification" == "Y" ]]; then

    verif_response=$(curl --insecure -s -X POST https://localhost:8799/attestation/sgx/dcap/v1/report -H "Content-Type: application/json" \
      -d '{
      "isvQuote": "'"$quote_encoded"'"
      }')

    print_info "Quote verification response:\n$verif_response"
  fi

  read -p "Continue with this server? (y/n): " continue_verification
  if [[ "$continue_verification" != "y" && "$continue_verification" != "Y" ]]; then
    print_warning "User aborted after quote verification"
    exit 0
  fi

  return 0
}

# Function to select a file for testing
select_file() {
  print_step "3" "Select a file to test"
  read -p "Enter the path to the file you want to test: " FILE_PATH

  if [[ ! -f "$FILE_PATH" ]]; then
    print_warning "File $FILE_PATH not found!"
    return 1
  fi

  return 0
}

# Function to get available tools
get_tools() {
  print_step "2" "Fetching available tools from server"

  if $LOCAL; then
    tools_response=$(curl -s -X POST "$SERVER_URL/tools" -k)
  else
    tools_response=$(curl -s -X POST "$SERVER_URL/tools" --cacert "$CERT_PATH")
  fi

  # Check if the response is valid JSON
  if ! echo "$tools_response" | jq . &>/dev/null; then
    print_warning "Failed to get tools or invalid response. Server may be down."
    echo "Raw response: $tools_response"
    exit 1
  fi

  # Extract tool names from response
  if command -v jq &>/dev/null; then
    available_tools=($(echo "$tools_response" | jq -r '.[].tool_name'))
  else
    available_tools=($(echo "$tools_response" | grep -o '"tool_name"[^,]*' | sed 's/"tool_name"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/'))
  fi

  if [[ ${#available_tools[@]} -eq 0 ]]; then
    print_warning "No tools available from server"
    exit 1
  fi

  print_info "Available tools: ${available_tools[*]}"
  return 0
}

# Function to select tool for testing
select_tool() {
  if [[ -z "$TOOL_NAME" ]]; then
    print_step "4" "Select a tool for testing"

    echo "Available tools:"
    for i in "${!available_tools[@]}"; do
      echo "  $((i + 1)). ${available_tools[$i]}"
    done

    read -p "Select a tool (number): " tool_num

    if [[ "$tool_num" -le "${#available_tools[@]}" && "$tool_num" -gt 0 ]]; then
      TOOL_NAME="${available_tools[$((tool_num - 1))]}"
    else
      print_warning "Invalid selection!"
      return 1
    fi
  else
    # Verify that the specified tool is available
    tool_found=false
    for t in "${available_tools[@]}"; do
      if [[ "$t" == "$TOOL_NAME" ]]; then
        tool_found=true
        break
      fi
    done

    if [[ "$tool_found" == false ]]; then
      print_warning "Specified tool '$TOOL_NAME' is not available on the server!"
      TOOL_NAME=""
      return 1
    fi

    print_step "4" "Using specified tool: $TOOL_NAME"
  fi

  print_info "Selected tool: $TOOL_NAME"
  return 0
}

# Function to upload the file and start analysis
upload_file() {
  print_step "5" "Uploading file and starting analysis"

  # Create temp file for payload
  temp_payload=$(mktemp)

  # Encode file as base64
  if [[ "$file_type" == "source" ]]; then
    TOE=$(base64 "$FILE_PATH")

    # Create payload for source code
    cat >"$temp_payload" <<EOF
{
  "toe": {
    "format": "string",
    "base64_encoded_toe": "$encoded_file"
  },
  "test_suite": [
    {
      "tool_name": "$TOOL_NAME",
      "parameters": null
    }
  ]
}
EOF
  else # binary
    TOE=$(base64 -w 0 "$FILE_PATH")

    # Create payload for binary
    cat >"$temp_payload" <<EOF
{
  "toe": {
    "format": "string",
    "base64_encoded_toe": "$encoded_file"
  },
  "test_suite": [
    {
      "tool_name": "$TOOL_NAME",
      "parameters": null
    }
  ]
}
EOF
  fi

  if $LOCAL; then
    echo '{
      "toe": {
        "format": "string",
        "base64_encoded_toe": "'"$TOE"'"
      },
      "test_suite": [
        {
          "tool_name": "'"$TOOL_NAME"'",
          "parameters": null
        }
      ]
    }' >./up_payload.tmp
    upload_response=$(curl -s -X POST -H "Content-Type: application/json" \
      -d @up_payload.tmp "$SERVER_URL/upload" -k)
    echo "Test1"
    echo "$upload_response"
    echo "Test2"
  else
    echo '{
      "toe": {
        "format": "string",
        "base64_encoded_toe": "'"$TOE"'"
      },
      "test_suite": [
        {
          "tool_name": "'"$TOOL_NAME"'",
          "parameters": null
        }
      ]
    }' >./up_payload.tmp
    upload_response=$(curl -s -X POST -H "Content-Type: application/json" \
      -d @up_payload.tmp \
      "$SERVER_URL/upload" --cacert "$CERT_PATH")
  fi

  # Clean up temp file
  rm "$temp_payload"
  rm ./up_payload.tmp

  # Check if the response is valid JSON
  if ! echo "$upload_response" | jq . &>/dev/null; then
    print_warning "Failed to upload file or invalid response."
    echo "test1"
    echo "Raw response: $upload_response"
    echo "test2"
    return 1
  fi

  JOB_ID=$(echo "$upload_response" | jq -r '.jobID')

  if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
    print_warning "Failed to get job ID from server response"
    echo "$upload_response" | jq .
    return 1
  fi

  print_info "File uploaded successfully. Job ID: $JOB_ID"
  read -p "Press Enter to start polling for results" </dev/tty
  return 0
}

# Function to poll for results
poll_results() {
  print_step "6" "Polling for results"

  print_info "Checking results for job ID: $JOB_ID"

  # Create temp file for payload
  temp_payload=$(mktemp)

  # Create payload for results request
  cat >"$temp_payload" <<EOF
{
  "identifier": "$JOB_ID"
}
EOF

  # Counter for polling attempts
  poll_count=0
  max_polls=30    # Maximum number of polling attempts
  poll_interval=2 # Seconds between polls

  while ((poll_count < max_polls)); do
    # Get results
    if $LOCAL; then
      results_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d @"$temp_payload" "$SERVER_URL/result" -k)
    else
      results_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d @"$temp_payload" "$SERVER_URL/result" --cacert "$CERT_PATH")
    fi

    # Check if the response is valid JSON
    if ! echo "$results_response" | jq . &>/dev/null; then
      print_warning "Failed to get results or invalid response."
      echo "Raw response: $results_response"
      ((poll_count < max_polls - 1)) || rm "$temp_payload" # Clean up if we're exiting
      return 1
    fi

    is_done=$(echo "$results_response" | jq -r '.status == "done"')

    if ($is_done == "true"); then
      rm "$temp_payload"
      break
    fi

    ((poll_count++))
    print_info "Analysis in progress... (attempt $poll_count/$max_polls)"
    sleep $poll_interval
  done

  # If we exit the loop normally, we have results
  if ((poll_count < max_polls)); then
    print_info "Analysis completed!"

    # Display results
    echo -e "\n${GREEN}=== Analysis Results ===${NC}"
    if command -v jq &>/dev/null && echo "$results_response" | jq . &>/dev/null; then
      # It's valid JSON and jq is available

      # extract signature
      SIGNATURE_BASE64=$(echo "$results_response" | jq -r '.crypto_verification_data')

      # extract message
      message=$(echo "$results_response" | jq -c 'del(.crypto_verification_data)')

      # Check if public key file exists
      if [ ! -f "$PUBLIC_KEY_FILE" ]; then
        echo "Error: Public key file not found: $PUBLIC_KEY_FILE"
        exit 1
      fi

      # Create temporary files
      TMP_DIR=$(mktemp -d)
      SIGNATURE_FILE="$TMP_DIR/signature.bin"
      MESSAGE_STRING_FILE="$TMP_DIR/message_string.txt"

      # Decode the base64 signature and message
      echo "$SIGNATURE_BASE64" | base64 -d >"$SIGNATURE_FILE"
      echo -n "$message" | iconv -t utf-8 >"$MESSAGE_STRING_FILE"

      signvalid=$(printf %s "$message" | openssl dgst -sha256 -verify "$PUBLIC_KEY_FILE" -signature "$SIGNATURE_FILE")
      # echo "signvalid: $signvalid"
      if [ "$signvalid" != "Verified OK" ]; then
        echo "Signature verification failed!"
        exit 1
      fi

      # Clean up
      rm -rf "$TMP_DIR"

      echo "$results_response" | jq .
    else
      # Either it's not JSON or jq isn't available
      echo "$results_response"
    fi

    # Check if we want to save the results
    read -p "Save results to file? (y/n): " save_results
    if [[ "$save_results" == "y" || "$save_results" == "Y" ]]; then
      read -p "Enter filename to save results (default: results_${JOB_ID}.json): " results_filename
      results_filename=${results_filename:-"results_${JOB_ID}.json"}
      echo "$results_response" >"$results_filename"
      print_info "Results saved to $results_filename"
    fi

    rm -f "$temp_payload"
    return 0
  else
    print_warning "Timed out waiting for results after $max_polls attempts"
    rm -f "$temp_payload"
    return 1
  fi
}

# Main function
main() {
  # Display welcome message
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}  Security Testing Interactive CLI Tool  ${NC}"
  echo -e "${BLUE}========================================${NC}\n"

  # Check if certificate exists
  check_certificate

  # Verify server (get quote)
  verify_server || exit 1

  # Get available tools
  get_tools || exit 1

  while true; do
    # Select file for testing
    while ! select_file; do
      print_warning "Please select a valid file"
    done

    # Select tool for testing
    while ! select_tool; do
      print_warning "Please select a valid tool"
    done

    # Upload file and start analysis
    upload_file || exit 1

    # Poll for results
    poll_results || exit 1

    read -p "Evaluate another file? (y/n): " again
    if [[ "$again" != "y" && "$continue_verification" != "Y" ]]; then
      break
      exit 0
    fi
    #reset chosen tool
    TOOL_NAME=
  done

  print_info "All done!"
}

# Run main function
main
