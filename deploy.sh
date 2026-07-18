#!/bin/bash

# ============================================================
# 🍂 Leef Panel - Setup Wizard
# ============================================================

clear

echo "==========================================="
echo "🍂 LEEF PANEL SETUP WIZARD"
echo "==========================================="
echo ""

# Get token
echo "Enter your Cloudflare API Token:"
echo "(Get from: https://dash.cloudflare.com/profile/api-tokens)"
echo ""
read -sp "> " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo "❌ Token is required"
    exit 1
fi

# Get Account ID
echo ""
echo "📡 Fetching Account ID..."
ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Invalid token or no permission"
    exit 1
fi

echo "✅ Account ID: $ACCOUNT_ID"

# Get worker name
echo ""
echo "Enter worker name (press Enter for random):"
read -p "> " WORKER_NAME
if [ -z "$WORKER_NAME" ]; then
    WORKER_NAME="leef-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)"
    echo "✅ Using: $WORKER_NAME"
fi

# Get panel name
echo ""
echo "Enter panel name (press Enter for default):"
read -p "> " PANEL_NAME
[ -z "$PANEL_NAME" ] && PANEL_NAME="LeefPanel"

# Get route
echo ""
echo "Enter API route (press Enter for default):"
read -p "> " API_ROUTE
[ -z "$API_ROUTE" ] && API_ROUTE="sync"

# Get master key
echo ""
echo "Enter master key (press Enter for random):"
read -sp "> " MASTER_KEY
echo ""
if [ -z "$MASTER_KEY" ]; then
    MASTER_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    echo "✅ Using: $MASTER_KEY"
fi

# Download worker code
echo ""
echo "📥 Downloading worker code..."
WORKER_CODE=$(curl -sSL "https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js" 2>/dev/null)

if [ -z "$WORKER_CODE" ]; then
    echo "❌ Could not download worker code"
    exit 1
fi

# Replace placeholders
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/MASTER_KEY_PLACEHOLDER/$MASTER_KEY/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/PANEL_NAME_PLACEHOLDER/$PANEL_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/WORKER_NAME_PLACEHOLDER/$WORKER_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s|API_ROUTE_PLACEHOLDER|$API_ROUTE|g")

# Deploy
echo ""
echo "🚀 Deploying to Cloudflare..."
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/javascript" \
    --data "$WORKER_CODE")

if echo "$RESPONSE" | grep -q '"success":true'; then
    clear
    echo "==========================================="
    echo "✅ DEPLOYMENT COMPLETE!"
    echo "==========================================="
    echo ""
    echo "📋 Panel Information:"
    echo ""
    echo "▶ Dashboard: https://$WORKER_NAME.workers.dev/$API_ROUTE/dash"
    echo "▶ Subscription: https://$WORKER_NAME.workers.dev/$API_ROUTE/sub"
    echo "▶ Master Key: $MASTER_KEY"
    echo "▶ Panel Name: $PANEL_NAME"
    echo ""
    echo "==========================================="
    echo "🍂 Thank you!"
    echo "==========================================="
else
    echo "❌ Deployment failed"
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    [ -n "$ERROR" ] && echo "Error: $ERROR"
    exit 1
fi
