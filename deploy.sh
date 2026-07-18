#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - Auto Deploy from GitHub
# Just enter API Token and Worker Name
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║        🍂 LEEF DEPLOY - AUTO v6.0                       ║"
echo "║                                                          ║"
echo "║     Enter API Token + Worker Name                       ║"
echo "║     Worker code auto-downloads from GitHub              ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# GET API TOKEN
# ============================================================

echo -e "\n${YELLOW}Enter Cloudflare API Token:${NC}"
echo -e "${YELLOW}(Get from: https://dash.cloudflare.com/profile/api-tokens)${NC}"
echo -e "${YELLOW}(Permissions: Workers Scripts:Edit, Account Settings:Read)${NC}\n"

read -sp "API Token: " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ API Token is required${NC}"
    exit 1
fi

# ============================================================
# GET ACCOUNT ID (AUTO)
# ============================================================

echo -e "\n${GREEN}▶${NC} Fetching Account ID..."

ACCOUNT_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

if echo "$ACCOUNT_RESPONSE" | grep -q '"success":false'; then
    echo -e "${RED}✗ Invalid API Token${NC}"
    exit 1
fi

ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Could not fetch Account ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Account ID: $ACCOUNT_ID"

# ============================================================
# GET WORKER NAME
# ============================================================

echo -e "\n${YELLOW}Enter worker name:${NC}"
read -p "> " WORKER_NAME

if [ -z "$WORKER_NAME" ]; then
    echo -e "${RED}✗ Worker name is required${NC}"
    exit 1
fi

# ============================================================
# GET PANEL SETTINGS (OPTIONAL)
# ============================================================

echo -e "\n${YELLOW}Panel settings (press Enter for defaults):${NC}"

read -p "Panel name [LeefPanel]: " PANEL_NAME
[ -z "$PANEL_NAME" ] && PANEL_NAME="LeefPanel"

read -p "API route [sync]: " API_ROUTE
[ -z "$API_ROUTE" ] && API_ROUTE="sync"

read -sp "Master key [admin123]: " MASTER_KEY
echo ""
[ -z "$MASTER_KEY" ] && MASTER_KEY="admin123"

# ============================================================
# DOWNLOAD WORKER CODE FROM GITHUB
# ============================================================

echo -e "\n${GREEN}▶${NC} Downloading worker code from GitHub..."

REPO_URL="https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js"
WORKER_RAW=$(curl -sSL "$REPO_URL" 2>/dev/null)

if [ -z "$WORKER_RAW" ] || echo "$WORKER_RAW" | grep -q "404: Not Found"; then
    echo -e "${YELLOW}⚠${NC} _worker.js not found, using built-in code..."
    
    # Built-in worker code
    WORKER_RAW='export default {
    async fetch(request) {
        return new Response("🍂 Leef Panel - Coming soon!", {
            headers: { "Content-Type": "text/html" }
        });
    }
};'
fi

# Replace placeholders
WORKER_CODE=$(echo "$WORKER_RAW" | sed "s/MASTER_KEY_PLACEHOLDER/$MASTER_KEY/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/PANEL_NAME_PLACEHOLDER/$PANEL_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/WORKER_NAME_PLACEHOLDER/$WORKER_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s|API_ROUTE_PLACEHOLDER|$API_ROUTE|g")

echo -e "${GREEN}✓${NC} Worker code ready"

# ============================================================
# DEPLOY
# ============================================================

echo -e "\n${GREEN}▶${NC} Deploying to Cloudflare..."

DEPLOY_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/javascript" \
    --data "$WORKER_CODE")

if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Deployment successful!"
else
    echo -e "${RED}✗${NC} Deployment failed"
    ERROR_MSG=$(echo "$DEPLOY_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    [ -n "$ERROR_MSG" ] && echo -e "${RED}Error: $ERROR_MSG${NC}"
    exit 1
fi

# ============================================================
# FINAL OUTPUT
# ============================================================

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           ✅ DEPLOYMENT COMPLETE!                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "\n${GREEN}${BOLD}🎉 Your Leef Panel is ready!${NC}"
echo -e "\n${GREEN}▶${NC} Dashboard: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/dash${NC}"
echo -e "${GREEN}▶${NC} Subscription: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/sub${NC}"
echo -e "${GREEN}▶${NC} Master Key: ${YELLOW}$MASTER_KEY${NC}"
echo -e "${GREEN}▶${NC} Panel Name: ${BOLD}$PANEL_NAME${NC}"
echo -e "${GREEN}▶${NC} Worker Name: ${BOLD}$WORKER_NAME${NC}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${GREEN}${BOLD}Thank you! 🍂${NC}\n"
