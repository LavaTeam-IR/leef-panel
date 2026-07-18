#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - Just Token
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
echo "║        🍂 LEEF DEPLOY - TOKEN ONLY v7.0                 ║"
echo "║                                                          ║"
echo "║     Just enter your Cloudflare API Token                 ║"
echo "║     Everything else is automatic!                       ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# GET TOKEN
# ============================================================

echo -e "\n${YELLOW}Enter Cloudflare API Token:${NC}"
echo -e "${YELLOW}(Get from: https://dash.cloudflare.com/profile/api-tokens)${NC}"
echo -e "${YELLOW}(Permissions: Workers Scripts:Edit, Account Settings:Read)${NC}\n"

read -sp "API Token: " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ Token required${NC}"
    exit 1
fi

# ============================================================
# AUTO GET ACCOUNT ID
# ============================================================

echo -e "\n${GREEN}▶${NC} Getting Account ID..."

ACCOUNT_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

if echo "$ACCOUNT_RESPONSE" | grep -q '"success":false'; then
    echo -e "${RED}✗ Invalid token${NC}"
    exit 1
fi

ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Could not get Account ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Account ID: $ACCOUNT_ID"

# ============================================================
# GET WORKER NAME
# ============================================================

echo -e "\n${YELLOW}Enter worker name:${NC}"
read -p "> " WORKER_NAME

if [ -z "$WORKER_NAME" ]; then
    WORKER_NAME="leef-panel"
    echo -e "${YELLOW}Using default: $WORKER_NAME${NC}"
fi

# ============================================================
# GET PANEL SETTINGS
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
# DOWNLOAD WORKER CODE
# ============================================================

echo -e "\n${GREEN}▶${NC} Downloading worker code..."

REPO_URL="https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js"
WORKER_RAW=$(curl -sSL "$REPO_URL" 2>/dev/null)

if [ -z "$WORKER_RAW" ]; then
    echo -e "${RED}✗ Could not download _worker.js${NC}"
    echo -e "${YELLOW}Make sure the file exists in your repository${NC}"
    exit 1
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

echo -e "\n${GREEN}▶${NC} Deploying..."

DEPLOY_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/javascript" \
    --data "$WORKER_CODE")

if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Deployed!"
else
    echo -e "${RED}✗${NC} Failed"
    exit 1
fi

# ============================================================
# DONE
# ============================================================

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           ✅ DEPLOYMENT COMPLETE!                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "\n${GREEN}${BOLD}🎉 Panel Ready!${NC}"
echo -e "\n${GREEN}▶${NC} Dashboard: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/dash${NC}"
echo -e "${GREEN}▶${NC} Master Key: ${YELLOW}$MASTER_KEY${NC}"
echo -e "\n${GREEN}Thank you! 🍂${NC}\n"
