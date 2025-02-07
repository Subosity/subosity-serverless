#!/bin/bash

set -euo pipefail

RED='\e[31m'
CYAN='\e[36m'
GREEN='\e[32m'
NC='\e[0m' # No Color

# Check required environment variables
: "${PROJECT_ID:?Environment variable PROJECT_ID is required}"
: "${SUPABASE_ANON_KEY:?Environment variable SUPABASE_ANON_KEY is required}"
: "${SUPABASE_URL:?Environment variable SUPABASE_URL is required}"

VERSION=$(date +"%Y.%m%d.%H%M")
export FUNCTION_VERSION=${VERSION}
echo -e "${CYAN}[*] Setting new function version to: ${VERSION}...${NC}"
echo "FUNCTION_VERSION=${VERSION}" >./version.env

echo -e "${CYAN}[*] Updating Supabase with the new function version: ${VERSION}...${NC}"
npx supabase secrets set --env-file ./version.env --project-ref $PROJECT_ID
status=$?
if [ $status -ne 0 ]; then
    echo -e "${RED}[-] Version update failed with exit code ${status}${NC}"
    exit 1
else
    echo -e "${GREEN}[+] Supabase function version updated successfully.${NC}"
fi

echo -e "${CYAN}[*] Running 'npx supabase functions deploy'...${NC}"
if [ -f ./.env ]; then
  source ./.env
fi

function deploy_endpoint() {
    label=$1
    func_name=$2
    echo -e "${CYAN}[*] Deploying '${label}' function...${NC}"
    npx supabase functions deploy "$func_name" --project-ref $PROJECT_ID
    status=$?
    if [ $status -ne 0 ]; then
        echo -e "${RED}[-] Deployment of '${label}' failed with exit code ${status}${NC}"
        exit 1
    else
        echo -e "${GREEN}[+] Supabase function: '${label}' deployed successfully.${NC}"
    fi
}

deploy_endpoint "fetch-metadata" "fetch-metadata"
deploy_endpoint "preprocess-notifications" "preprocess-notifications"
deploy_endpoint "process-notifications" "process-notifications"

TIMEOUT_FLAGS="--max-time 10 --connect-timeout 10" # -v"

function test_endpoint() {
    label=$1
    url=$2

    echo -e "${CYAN}[*] Testing ${label}...${NC}"
    response=$(curl -s -L -X POST "${url}" \
        -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json" $TIMEOUT_FLAGS)
    status=$?
    if [ $status -ne 0 ]; then
        echo -e "${RED}[-] Request to '${label}' failed with exit code ${status}${NC}"
        exit 1
    else
        echo -e "${GREEN}[+] Success.${NC}"
        echo "$response" | jq
    fi
}

test_endpoint "preprocess-notifications/healthcheck" "${SUPABASE_URL}/functions/v1/preprocess-notifications/healthcheck"
test_endpoint "process-notifications/healthcheck" "${SUPABASE_URL}/functions/v1/process-notifications/healthcheck"
test_endpoint "fetch-metadata/healthcheck" "${SUPABASE_URL}/functions/v1/fetch-metadata/healthcheck"
test_endpoint "fetch-metadata with domain parameter" "${SUPABASE_URL}/functions/v1/fetch-metadata?domain=subosity.com"

echo -e "${CYAN}[*] Cleaning up temporary files...${NC}"
rm -f ./version.env