#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - With D1 Database
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
echo "║           🍂 LEEF DEPLOY - WITH D1                       ║
echo "║                                                          ║
echo "║     Deploy Worker + Create & Bind D1 Database           ║
echo "║                                                          ║
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# GET TOKEN
# ============================================================

echo -e "\n${YELLOW}Enter Cloudflare API Token:${NC}"
read -sp "> " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ Token required${NC}"
    exit 1
fi

# ============================================================
# GET ACCOUNT ID
# ============================================================

echo -e "\n${GREEN}▶${NC} Getting Account ID..."

ACCOUNT_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Invalid token${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Account ID: $ACCOUNT_ID"

# ============================================================
# GENERATE RANDOM SETTINGS
# ============================================================

RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
WORKER_NAME="leef-${RAND}"
DB_NAME="leef-db-${RAND}"
API_ROUTE=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
MASTER_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

echo -e "\n${GREEN}▶${NC} Generated settings:"
echo -e "   Worker: ${BOLD}$WORKER_NAME${NC}"
echo -e "   Database: ${BOLD}$DB_NAME${NC}"
echo -e "   Route: ${BOLD}$API_ROUTE${NC}"

# ============================================================
# CREATE D1 DATABASE
# ============================================================

echo -e "\n${GREEN}▶${NC} Creating D1 database..."

DB_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/d1/database" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$DB_NAME\"}")

DB_UUID=$(echo "$DB_RESPONSE" | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)

if [ -z "$DB_UUID" ]; then
    echo -e "${RED}✗ Failed to create D1 database${NC}"
    echo "$DB_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} Database created: $DB_UUID"

# ============================================================
# DOWNLOAD WORKER CODE
# ============================================================

echo -e "\n${GREEN}▶${NC} Downloading worker code..."

WORKER_CODE=$(curl -sSL "https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js" 2>/dev/null)

if [ -z "$WORKER_CODE" ]; then
    echo -e "${RED}✗ Could not download _worker.js${NC}"
    exit 1
fi

# Replace placeholders (just in case)
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/MASTER_KEY_PLACEHOLDER/$MASTER_KEY/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/PANEL_NAME_PLACEHOLDER/LeefPanel/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/WORKER_NAME_PLACEHOLDER/$WORKER_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s|API_ROUTE_PLACEHOLDER|$API_ROUTE|g")

echo -e "${GREEN}✓${NC} Worker code ready"

# ============================================================
# DEPLOY WORKER WITH D1 BINDING
# ============================================================

echo -e "\n${GREEN}▶${NC} Deploying worker with D1 binding..."

# Deploy worker
DEPLOY_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/javascript" \
    --data "$WORKER_CODE")

if ! echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo -e "${RED}✗ Worker deployment failed${NC}"
    echo "$DEPLOY_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} Worker deployed"

# ============================================================
# BIND D1 TO WORKER
# ============================================================

echo -e "\n${GREEN}▶${NC} Binding D1 to worker..."

BIND_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME/bindings" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
        \"bindings\": [
            {
                \"type\": \"d1\",
                \"name\": \"IOT_DB\",
                \"database_id\": \"$DB_UUID\"
            }
        ]
    }")

if ! echo "$BIND_RESPONSE" | grep -q '"success":true'; then
    echo -e "${RED}✗ Failed to bind D1${NC}"
    echo "$BIND_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} D1 bound to worker"

# ============================================================
# FINAL OUTPUT
# ============================================================

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           ✅ DEPLOYMENT COMPLETE!                        ║
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "\n${GREEN}${BOLD}🎉 Your Leef Panel is ready!${NC}"
echo -e "\n${GREEN}📋${NC} ${BOLD}Panel Information:${NC}"
echo -e "\n${GREEN}▶${NC} Dashboard: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/dash${NC}"
echo -e "${GREEN}▶${NC} Subscription: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/sub${NC}"
echo -e "${GREEN}▶${NC} Master Key: ${YELLOW}$MASTER_KEY${NC}"
echo -e "${GREEN}▶${NC} Worker: ${BOLD}$WORKER_NAME${NC}"
echo -e "${GREEN}▶${NC} Database: ${BOLD}$DB_NAME${NC}"

# Save info
cat > leef_info.txt << EOF
=============================================
🍂 LEEF PANEL DEPLOYMENT INFORMATION
=============================================
Dashboard: https://$WORKER_NAME.workers.dev/$API_ROUTE/dash
Subscription: https://$WORKER_NAME.workers.dev/$API_ROUTE/sub
Master Key: $MASTER_KEY
Worker Name: $WORKER_NAME
Database Name: $DB_NAME
Database ID: $DB_UUID
API Route: $API_ROUTE
=============================================
EOF

echo -e "\n${YELLOW}💾 Info saved to: leef_info.txt${NC}"
echo -e "\n${GREEN}${BOLD}Thank you! 🍂${NC}\n"
