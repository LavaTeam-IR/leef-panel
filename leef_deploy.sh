#!/bin/bash

# ============================================================
# 🍂 Leef Deploy Script - Cloudflare Worker Deployment
# Version: 3.0.0
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║           🍂 LEEF DEPLOY SCRIPT v3.0                    ║"
    echo "║                                                          ║"
    echo "║     Deploy to Cloudflare Workers with Token              ║"
    echo "║                                                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}▶${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# ============================================================
# CHECK AND INSTALL DEPENDENCIES
# ============================================================

print_header

print_step "Checking system and installing dependencies..."

# Detect OS and package manager
if command -v pkg &> /dev/null; then
    # Termux
    PKG_MANAGER="pkg"
    INSTALL_CMD="pkg install -y"
    echo -e "${BLUE}Detected: Termux${NC}"
elif command -v apt &> /dev/null; then
    # Debian/Ubuntu
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt install -y"
    echo -e "${BLUE}Detected: Debian/Ubuntu${NC}"
elif command -v yum &> /dev/null; then
    # RHEL/CentOS
    PKG_MANAGER="yum"
    INSTALL_CMD="sudo yum install -y"
    echo -e "${BLUE}Detected: RHEL/CentOS${NC}"
else
    print_error "Unsupported package manager. Please install: curl, jq, nodejs"
    exit 1
fi

# Install system packages
print_info "Installing system packages..."

if [ "$PKG_MANAGER" = "pkg" ]; then
    # Termux
    pkg update -y
    pkg install -y curl jq nodejs
else
    # Linux
    $INSTALL_CMD curl jq nodejs npm
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js installation failed"
    exit 1
fi

print_success "Node.js: $(node --version)"

# Install Wrangler via npm
print_info "Installing Wrangler via npm..."

npm install -g wrangler 2>/dev/null

if [ $? -ne 0 ]; then
    print_error "Failed to install Wrangler via npm"
    print_info "Trying with sudo..."
    sudo npm install -g wrangler 2>/dev/null || {
        print_error "Please install Wrangler manually: npm install -g wrangler"
        exit 1
    }
fi

if ! command -v wrangler &> /dev/null; then
    # Try to find wrangler in npm global path
    NPM_GLOBAL=$(npm root -g)
    WRANGLER_PATH="$NPM_GLOBAL/wrangler/bin/wrangler.js"
    if [ -f "$WRANGLER_PATH" ]; then
        export PATH="$PATH:$(dirname $WRANGLER_PATH)"
        alias wrangler="node $WRANGLER_PATH"
    else
        print_error "Wrangler not found in PATH"
        print_info "You may need to restart your terminal or run: export PATH=\"\$PATH:\$(npm root -g)/wrangler/bin\""
        exit 1
    fi
fi

print_success "Wrangler: $(wrangler --version 2>/dev/null || echo 'installed')"

# ============================================================
# GET CLOUDFLARE CREDENTIALS
# ============================================================

print_step "Cloudflare Authentication"

echo -e "\n${YELLOW}Enter your Cloudflare credentials:${NC}"
echo -e "${YELLOW}(Get API Token from: https://dash.cloudflare.com/profile/api-tokens)${NC}"
echo -e "${YELLOW}Token needs permissions: Workers, D1, Account Settings${NC}\n"

read -p "Cloudflare Email: " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    print_error "Email cannot be empty"
    exit 1
fi

read -sp "Cloudflare API Token: " CF_API_TOKEN
echo ""
if [ -z "$CF_API_TOKEN" ]; then
    print_error "API Token cannot be empty"
    exit 1
fi

# Verify credentials
print_info "Verifying credentials..."

VERIFY_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

if echo "$VERIFY_RESPONSE" | grep -q '"success":true'; then
    print_success "Authentication successful!"
else
    print_error "Authentication failed. Please check your API Token."
    exit 1
fi

# Get Account ID
ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    print_error "Could not fetch Account ID"
    exit 1
fi
print_success "Account ID: $ACCOUNT_ID"

# ============================================================
# GET CONFIGURATION
# ============================================================

print_step "Panel Configuration"

echo -e "\n${YELLOW}Enter your panel settings:${NC}\n"

read -p "Worker name (e.g., leef-panel): " WORKER_NAME
if [ -z "$WORKER_NAME" ]; then
    WORKER_NAME="leef-panel"
    print_info "Using default: $WORKER_NAME"
fi

read -p "Panel name (e.g., MyLeefPanel): " PANEL_NAME
if [ -z "$PANEL_NAME" ]; then
    PANEL_NAME="LeefPanel"
    print_info "Using default: $PANEL_NAME"
fi

read -p "API route (e.g., secret123): " API_ROUTE
if [ -z "$API_ROUTE" ]; then
    API_ROUTE="sync"
    print_info "Using default: $API_ROUTE"
fi

read -sp "Master key (min 6 chars): " MASTER_KEY
echo ""
if [ -z "$MASTER_KEY" ]; then
    MASTER_KEY="admin123"
    print_info "Using default: $MASTER_KEY (Please change this!)"
elif [ ${#MASTER_KEY} -lt 6 ]; then
    print_error "Master key must be at least 6 characters"
    exit 1
fi

# ============================================================
# GENERATE WORKER CODE
# ============================================================

print_step "Generating worker code..."

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Get the actual worker code from GitHub
print_info "Downloading worker code from repository..."
curl -sSL -o _worker.js "https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js"

if [ ! -f "_worker.js" ]; then
    print_error "Failed to download worker code"
    print_info "Creating fallback worker code..."
    
    # Fallback: Generate simple worker
    cat > _worker.js << EOF
// Fallback worker - will be replaced with full version
export default {
  async fetch(request) {
    return new Response('Leef Panel - Coming soon!', {
      headers: { 'Content-Type': 'text/html' }
    });
  }
}
EOF
fi

# ============================================================
# DEPLOY WORKER
# ============================================================

print_step "Deploying to Cloudflare Workers"

# Login using API token
print_info "Authenticating with Cloudflare..."
wrangler login --api-token "$CF_API_TOKEN" 2>/dev/null

# Create wrangler.toml
cat > wrangler.toml << EOF
name = "$WORKER_NAME"
main = "_worker.js"
compatibility_date = "2024-01-01"
account_id = "$ACCOUNT_ID"

[vars]
PANEL_NAME = "$PANEL_NAME"
API_ROUTE = "$API_ROUTE"
MASTER_KEY = "$MASTER_KEY"
EOF

# Deploy
print_info "Deploying $WORKER_NAME..."

# Use wrangler with node if needed
if command -v wrangler &> /dev/null; then
    DEPLOY_OUTPUT=$(wrangler deploy --yes 2>&1)
else
    # Try using npx
    if command -v npx &> /dev/null; then
        DEPLOY_OUTPUT=$(npx wrangler deploy --yes 2>&1)
    else
        print_error "Cannot find wrangler command"
        exit 1
    fi
fi

if [ $? -eq 0 ]; then
    print_success "Deployment successful!"
    
    # Extract worker URL
    WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -o "https://[^ ]*\.workers\.dev" | head -1)
    if [ -z "$WORKER_URL" ]; then
        WORKER_URL="https://$WORKER_NAME.workers.dev"
    fi
else
    print_error "Deployment failed"
    print_info "Error details:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# ============================================================
# FINAL OUTPUT
# ============================================================

cd ~
clear
print_header

echo -e "\n${GREEN}${BOLD}✅ DEPLOYMENT COMPLETE!${NC}\n"

echo -e "${BOLD}📋 Your Leef Panel Details:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${GREEN}▶${NC} ${BOLD}Panel Name:${NC} $PANEL_NAME"
echo -e "${GREEN}▶${NC} ${BOLD}Worker Name:${NC} $WORKER_NAME"
echo -e "${GREEN}▶${NC} ${BOLD}Dashboard URL:${NC} ${YELLOW}${WORKER_URL}/${API_ROUTE}/dash${NC}"
echo -e "${GREEN}▶${NC} ${BOLD}Subscription URL:${NC} ${YELLOW}${WORKER_URL}/${API_ROUTE}/sub${NC}"
echo -e "${GREEN}▶${NC} ${BOLD}Master Key:${NC} ${YELLOW}$MASTER_KEY${NC} ${RED}(Save this!)${NC}"
echo -e "${GREEN}▶${NC} ${BOLD}API Route:${NC} $API_ROUTE"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${YELLOW}${BOLD}⚠️  IMPORTANT:${NC}"
echo -e "1. Access your panel at: ${WORKER_URL}/${API_ROUTE}/dash"
echo -e "2. Login with master key: ${MASTER_KEY}"
echo -e "3. Change your master key in the settings!"
echo -e "4. Share the subscription link with your users"

# Save deployment info
cat > ~/leef_deployment_info.txt << EOF
=============================================
🍂 LEEF PANEL DEPLOYMENT INFORMATION
=============================================
Deployment Date: $(date)
Panel Name: $PANEL_NAME
Worker Name: $WORKER_NAME
Dashboard URL: ${WORKER_URL}/${API_ROUTE}/dash
Subscription URL: ${WORKER_URL}/${API_ROUTE}/sub
Master Key: $MASTER_KEY
API Route: $API_ROUTE
Account ID: $ACCOUNT_ID
=============================================
EOF

print_success "Deployment information saved to ~/leef_deployment_info.txt"

echo -e "\n${GREEN}${BOLD}Thank you for using Leef Panel! 🍂${NC}\n"

# Cleanup
rm -rf $TEMP_DIR
