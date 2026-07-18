#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - Fully Automatic
# Just enter token, we do the rest!
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
echo "║        🍂 LEEF DEPLOY - FULL AUTO v8.0                  ║"
echo "║                                                          ║"
echo "║     Just send your token and we handle everything!      ║"
echo "║     Random worker name, auto deploy, instant panel!     ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# GET TOKEN
# ============================================================

echo -e "\n${YELLOW}📝 Send your Cloudflare API Token:${NC}"
echo -e "${YELLOW}(Get from: https://dash.cloudflare.com/profile/api-tokens)${NC}"
echo -e "${YELLOW}(Permissions: Workers Scripts:Edit, Account Settings:Read)${NC}\n"

read -sp "➜ " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ Token is required!${NC}"
    exit 1
fi

# ============================================================
# GET ACCOUNT ID
# ============================================================

echo -e "\n${GREEN}▶${NC} Verifying token..."

ACCOUNT_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

if echo "$ACCOUNT_RESPONSE" | grep -q '"success":false'; then
    echo -e "${RED}✗ Invalid token!${NC}"
    exit 1
fi

ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Could not get Account ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Token verified!"

# ============================================================
# GENERATE RANDOM WORKER NAME
# ============================================================

RANDOM_WORDS=("leef" "panel" "gate" "proxy" "cloud" "edge" "node" "core" "main" "hub")
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
WORKER_NAME="${RANDOM_WORDS[$RANDOM % ${#RANDOM_WORDS[@]}]}-${RANDOM_SUFFIX}"

echo -e "\n${GREEN}▶${NC} Generated worker name: ${BOLD}$WORKER_NAME${NC}"

# ============================================================
# GENERATE RANDOM PANEL SETTINGS
# ============================================================

PANEL_NAME="Leef-$(cat /dev/urandom | tr -dc 'A-Z' | fold -w 4 | head -n 1)"
API_ROUTE=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
MASTER_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

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
echo -e "${GREEN}▶${NC} API Route: ${BOLD}$API_ROUTE${NC}"
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${YELLOW}💾 Info saved to: leef_info.txt${NC}"
echo -e "\n${GREEN}${BOLD}Thank you! 🍂${NC}\n"
