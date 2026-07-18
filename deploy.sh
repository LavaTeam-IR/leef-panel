#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - One Click Deploy
# Just enter worker name and done!
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║        🍂 LEEF DEPLOY - ONE CLICK v5.0                  ║"
echo "║                                                          ║"
echo "║     Just enter worker name and we handle the rest!      ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# CONFIGURATION (EDIT THESE)
# ============================================================

# Your Cloudflare API Token (Get from: https://dash.cloudflare.com/profile/api-tokens)
# Token needs: Workers Scripts:Edit, Account Settings:Read
CF_API_TOKEN="YOUR_API_TOKEN_HERE"

# Your Account ID (Get from: https://dash.cloudflare.com/)
ACCOUNT_ID="YOUR_ACCOUNT_ID_HERE"

# Repository with worker code
REPO_URL="https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js"

# ============================================================
# GET WORKER NAME
# ============================================================

echo -e "\n${YELLOW}Enter your worker name:${NC}"
read -p "> " WORKER_NAME

if [ -z "$WORKER_NAME" ]; then
    echo -e "${RED}✗ Worker name is required${NC}"
    exit 1
fi

# ============================================================
# DOWNLOAD WORKER CODE
# ============================================================

echo -e "\n${GREEN}▶${NC} Downloading worker code from GitHub..."

WORKER_CODE=$(curl -sSL "$REPO_URL" 2>/dev/null)

if [ -z "$WORKER_CODE" ] || echo "$WORKER_CODE" | grep -q "404: Not Found"; then
    echo -e "${YELLOW}⚠${NC} _worker.js not found, using built-in code..."
    
    # Built-in worker (minimal version)
    WORKER_CODE='export default { async fetch(request) { return new Response("🍂 Leef Panel - Coming soon!", { headers: { "Content-Type": "text/html" } }); } };'
fi

echo -e "${GREEN}✓${NC} Worker code ready (${#WORKER_CODE} bytes)"

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

echo -e "\n${GREEN}${BOLD}🎉 Your Leef Panel is ready!${NC}"
echo -e "\n${GREEN}▶${NC} URL: ${YELLOW}https://$WORKER_NAME.workers.dev${NC}"
echo -e "${GREEN}▶${NC} Dashboard: ${YELLOW}https://$WORKER_NAME.workers.dev/sync/dash${NC}"
echo -e "${GREEN}▶${NC} Panel: ${BOLD}Leef Panel${NC}"
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
