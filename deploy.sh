#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - Token Check + Deploy
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
echo "║        🍂 LEEF DEPLOY - TOKEN CHECK v9.0                ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# GET TOKEN
# ============================================================

echo -e "\n${YELLOW}📝 Send your Cloudflare API Token:${NC}"
echo -e "${YELLOW}(Get from: https://dash.cloudflare.com/profile/api-tokens)${NC}"
echo -e "${YELLOW}(Permissions needed: Workers Scripts:Edit, Account Settings:Read)${NC}\n"

read -sp "➜ " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ Token is required!${NC}"
    exit 1
fi

# ============================================================
# TEST TOKEN
# ============================================================

echo -e "\n${GREEN}▶${NC} Testing token..."

# Test 1: Verify token
VERIFY_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

echo -e "${YELLOW}Debug - Verify response:${NC}"
echo "$VERIFY_RESPONSE" | jq '.' 2>/dev/null || echo "$VERIFY_RESPONSE"

if echo "$VERIFY_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Token is valid!"
else
    echo -e "${RED}✗ Invalid token!${NC}"
    ERROR_MSG=$(echo "$VERIFY_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    [ -n "$ERROR_MSG" ] && echo -e "${RED}Error: $ERROR_MSG${NC}"
    exit 1
fi

# ============================================================
# GET ACCOUNT ID
# ============================================================

echo -e "\n${GREEN}▶${NC} Getting Account ID..."

ACCOUNT_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

if echo "$ACCOUNT_RESPONSE" | grep -q '"success":false'; then
    echo -e "${RED}✗ Could not get accounts${NC}"
    echo "$ACCOUNT_RESPONSE" | jq '.' 2>/dev/null || echo "$ACCOUNT_RESPONSE"
    exit 1
fi

ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Could not get Account ID${NC}"
    echo "$ACCOUNT_RESPONSE" | jq '.' 2>/dev/null || echo "$ACCOUNT_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} Account ID: $ACCOUNT_ID"

# ============================================================
# GENERATE RANDOM SETTINGS
# ============================================================

RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
WORKER_NAME="leef-${RANDOM_SUFFIX}"
PANEL_NAME="Leef-$(cat /dev/urandom | tr -dc 'A-Z' | fold -w 4 | head -n 1)"
API_ROUTE=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
MASTER_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

echo -e "\n${GREEN}▶${NC} Generated settings:"
echo -e "   Worker: ${BOLD}$WORKER_NAME${NC}"
echo -e "   Panel: ${BOLD}$PANEL_NAME${NC}"
echo -e "   Route: ${BOLD}$API_ROUTE${NC}"

# ============================================================
# DOWNLOAD WORKER CODE
# ============================================================

echo -e "\n${GREEN}▶${NC} Downloading worker code..."

REPO_URL="https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js"
WORKER_RAW=$(curl -sSL "$REPO_URL" 2>/dev/null)

if [ -z "$WORKER_RAW" ]; then
    echo -e "${RED}✗ Could not download _worker.js${NC}"
    echo -e "${YELLOW}Using built-in fallback...${NC}"
    
    WORKER_RAW='export default {
    async fetch(request) {
        return new Response("🍂 Leef Panel - Ready!", {
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

echo -e "${GREEN}✓${NC} Worker code ready (${#WORKER_CODE} bytes)"

# ============================================================
# DEPLOY
# ============================================================

echo -e "\n${GREEN}▶${NC} Deploying to Cloudflare..."

DEPLOY_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/javascript" \
    --data "$WORKER_CODE")

echo -e "${YELLOW}Debug - Deploy response:${NC}"
echo "$DEPLOY_RESPONSE" | jq '.' 2>/dev/null || echo "$DEPLOY_RESPONSE"

if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Deployment successful!"
else
    echo -e "${RED}✗${NC} Deployment failed"
    
    # Extract error
    ERROR_MSG=$(echo "$DEPLOY_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$ERROR_MSG" ]; then
        echo -e "${RED}Error: $ERROR_MSG${NC}"
    fi
    
    # Check for specific errors
    if echo "$DEPLOY_RESPONSE" | grep -q "not found"; then
        echo -e "${YELLOW}⚠${NC} Make sure your token has 'Workers Scripts:Edit' permission"
    fi
    
    exit 1
fi

# ============================================================
# SAVE INFO
# ============================================================

cat > leef_info.txt << EOF
=============================================
🍂 LEEF PANEL DEPLOYMENT INFORMATION
=============================================
Dashboard: https://$WORKER_NAME.workers.dev/$API_ROUTE/dash
Subscription: https://$WORKER_NAME.workers.dev/$API_ROUTE/sub
Master Key: $MASTER_KEY
Panel Name: $PANEL_NAME
Worker Name: $WORKER_NAME
API Route: $API_ROUTE
=============================================
EOF

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
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${GREEN}📋${NC} ${BOLD}Panel Information:${NC}"
echo -e "\n${GREEN}▶${NC} Dashboard URL: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/dash${NC}"
echo -e "${GREEN}▶${NC} Subscription URL: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/sub${NC}"
echo -e "${GREEN}▶${NC} Master Key: ${YELLOW}$MASTER_KEY${NC}"
echo -e "${GREEN}▶${NC} Panel Name: ${BOLD}$PANEL_NAME${NC}"
echo -e "${GREEN}▶${NC} Worker Name: ${BOLD}$WORKER_NAME${NC}"
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${YELLOW}💾 Info saved to: leef_info.txt${NC}"
echo -e "\n${GREEN}${BOLD}Thank you! 🍂${NC}\n"
