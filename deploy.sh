#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - Final Version
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║           🍂 LEEF DEPLOY - FINAL v12.0                  ║"
echo "║                                                          ║"
echo "║        Just enter your token and we deploy!             ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "\n${YELLOW}Enter Cloudflare API Token:${NC}"
read -sp "> " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ Token required${NC}"
    exit 1
fi

# Get Account ID
ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Invalid token or no permission${NC}"
    echo -e "${YELLOW}Make sure your token has: Workers Scripts:Edit${NC}"
    exit 1
fi

# Generate random names
RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
WORKER_NAME="leef-${RAND}"
API_ROUTE=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
MASTER_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

# Download worker code
WORKER_CODE=$(curl -sSL "https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js" 2>/dev/null)

if [ -z "$WORKER_CODE" ]; then
    echo -e "${YELLOW}⚠ Using built-in code${NC}"
    WORKER_CODE='export default { async fetch() { return new Response("🍂 Leef Panel Ready"); } };'
fi

# Replace placeholders
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/MASTER_KEY_PLACEHOLDER/$MASTER_KEY/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/PANEL_NAME_PLACEHOLDER/LeefPanel/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/WORKER_NAME_PLACEHOLDER/$WORKER_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s|API_ROUTE_PLACEHOLDER|$API_ROUTE|g")

# Deploy
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/javascript" \
    --data "$WORKER_CODE")

if echo "$RESPONSE" | grep -q '"success":true'; then
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           ✅ DEPLOYMENT COMPLETE!                        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "\n${GREEN}${BOLD}🎉 Panel Ready!${NC}"
    echo -e "\n${GREEN}▶${NC} URL: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/dash${NC}"
    echo -e "${GREEN}▶${NC} Key: ${YELLOW}$MASTER_KEY${NC}"
    echo -e "\n${GREEN}Thank you! 🍂${NC}\n"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$ERROR" ]; then
        echo -e "${RED}Error: $ERROR${NC}"
    fi
    exit 1
fi
