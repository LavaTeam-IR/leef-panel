#!/bin/bash

# ============================================================
# 🍂 Leef Deploy Script - Cloudflare Worker Deployment
# Version: 3.0.0
# Description: Deploy Leef Panel on Cloudflare Workers
# ============================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================================
# FUNCTIONS
# ============================================================

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

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed."
        return 1
    fi
    return 0
}

# ============================================================
# MAIN SCRIPT
# ============================================================

print_header

# Check requirements
print_step "Checking requirements..."

REQUIRED_OK=1
check_command "curl" || REQUIRED_OK=0
check_command "jq" || REQUIRED_OK=0
check_command "node" || REQUIRED_OK=0

if [ $REQUIRED_OK -eq 0 ]; then
    print_error "Missing required packages. Installing..."
    
    # Detect package manager
    if command -v pkg &> /dev/null; then
        # Termux
        pkg update -y
        pkg install -y curl jq nodejs
    elif command -v apt &> /dev/null; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y curl jq nodejs npm
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        sudo yum install -y curl jq nodejs npm
    else
        print_error "Please install: curl, jq, nodejs"
        exit 1
    fi
fi

# Install Wrangler if not installed
if ! command -v wrangler &> /dev/null; then
    print_info "Installing Wrangler..."
    npm install -g wrangler
    if [ $? -ne 0 ]; then
        print_error "Failed to install Wrangler"
        exit 1
    fi
fi

print_success "All requirements satisfied"

# ============================================================
# GET CLOUDFLARE CREDENTIALS
# ============================================================

print_step "Cloudflare Authentication"

echo -e "\n${YELLOW}Enter your Cloudflare credentials:${NC}"
echo -e "${YELLOW}(Get API Token from: https://dash.cloudflare.com/profile/api-tokens)${NC}\n"

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
    -H "Content-Type: application/json" | jq -r '.result.id')

if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "null" ]; then
    print_error "Could not fetch Account ID"
    exit 1
fi
print_success "Account ID: $ACCOUNT_ID"

# ============================================================
# GET CONFIGURATION
# ============================================================

print_step "Configuration"

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

print_step "Generating Worker code"

cat > _worker.js << 'EOF'
// ============================================================
// 🍂leef - Cloudflare Worker Panel
// Version: 3.0.0
// ============================================================

const CONFIG = {
    APP_NAME: '🍂leef',
    VERSION: '3.0.0',
    DEFAULT_ROUTE: 'sync',
    DEFAULT_MASTER_KEY: 'admin123'
};

// HTML Dashboard
function getDashboardHTML(route) {
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🍂 Leef Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: #f3f4f6;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 28px;
            color: #dc2626;
        }
        .header p {
            color: #6b7280;
            margin-top: 5px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            font-weight: 600;
            margin-bottom: 5px;
            color: #374151;
        }
        input {
            width: 100%;
            padding: 12px;
            border: 2px solid #e5e7eb;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.2s;
        }
        input:focus {
            outline: none;
            border-color: #dc2626;
        }
        .btn {
            width: 100%;
            padding: 12px;
            background: #dc2626;
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s;
        }
        .btn:hover {
            background: #b91c1c;
        }
        .error {
            color: #dc2626;
            font-size: 14px;
            margin-top: 10px;
            display: none;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #9ca3af;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🍂 Leef Panel</h1>
            <p>Enter your master key to continue</p>
        </div>
        <form onsubmit="authenticate(event)">
            <div class="form-group">
                <label for="masterKey">Master Key</label>
                <input type="password" id="masterKey" placeholder="Enter master key..." required>
            </div>
            <button type="submit" class="btn">Authenticate</button>
            <div id="error" class="error">Invalid master key. Please try again.</div>
        </form>
        <div class="footer">
            🍂 Leef Panel v3.0
        </div>
    </div>
    <script>
        async function authenticate(e) {
            e.preventDefault();
            const key = document.getElementById('masterKey').value;
            
            try {
                const response = await fetch('/api/auth', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ key: key })
                });
                
                if (response.ok) {
                    const data = await response.json();
                    // Store token and redirect
                    document.cookie = 'auth=' + data.token + ';path=/;max-age=86400';
                    window.location.href = '/${route}/dashboard';
                } else {
                    document.getElementById('error').style.display = 'block';
                }
            } catch (error) {
                document.getElementById('error').style.display = 'block';
            }
        }
    </script>
</body>
</html>
    `;
}

// Main Worker handler
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const path = url.pathname;
        
        // Initialize storage (using KV or D1 would be better)
        const ROUTE = '${API_ROUTE}';
        const MASTER_KEY = '${MASTER_KEY}';
        
        // Dashboard route
        if (path === '/${API_ROUTE}/dash' || path === '/${API_ROUTE}') {
            return new Response(getDashboardHTML(ROUTE), {
                headers: { 'Content-Type': 'text/html;charset=utf-8' }
            });
        }
        
        // Authentication
        if (path === '/api/auth' && request.method === 'POST') {
            try {
                const data = await request.json();
                if (data.key === MASTER_KEY) {
                    const token = btoa(Date.now() + ':' + Math.random());
                    return new Response(JSON.stringify({ 
                        success: true, 
                        token: token,
                        redirect: '/${API_ROUTE}/dashboard'
                    }), {
                        headers: { 'Content-Type': 'application/json' }
                    });
                } else {
                    return new Response(JSON.stringify({ success: false }), {
                        status: 401,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
            } catch (e) {
                return new Response(JSON.stringify({ success: false }), { status: 400 });
            }
        }
        
        // Protected dashboard
        if (path === '/${API_ROUTE}/dashboard') {
            // Check auth cookie
            const cookies = request.headers.get('Cookie') || '';
            if (!cookies.includes('auth=')) {
                return Response.redirect('/${API_ROUTE}/dash', 302);
            }
            
            return new Response(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🍂 Leef Panel - Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: system-ui, sans-serif;
            background: #f3f4f6;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: linear-gradient(135deg, #dc2626, #991b1b);
            color: white;
            padding: 30px;
            border-radius: 16px;
            margin-bottom: 30px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 { font-size: 28px; }
        .card {
            background: white;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .card h2 {
            color: #dc2626;
            margin-bottom: 15px;
        }
        .btn {
            padding: 10px 20px;
            background: #dc2626;
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
        }
        .btn:hover { background: #b91c1c; }
        .btn-danger { background: #991b1b; }
        .btn-danger:hover { background: #7f1d1d; }
        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        @media (max-width: 768px) { .grid-2 { grid-template-columns: 1fr; } }
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        .status-online { background: #dcfce7; color: #166534; }
        .status-offline { background: #fee2e2; color: #991b1b; }
        input, select {
            width: 100%;
            padding: 10px;
            border: 1px solid #d1d5db;
            border-radius: 8px;
            margin-bottom: 10px;
        }
        .flex { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
        .flex-between { display: flex; justify-content: space-between; align-items: center; }
        .text-red { color: #dc2626; }
        .text-white { color: white; }
        .mt-10 { margin-top: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🍂 ${PANEL_NAME}</h1>
            <div class="flex">
                <span class="status-badge status-online">● Active</span>
                <button class="btn btn-danger" onclick="logout()">Logout</button>
            </div>
        </div>
        
        <div class="grid-2">
            <div class="card">
                <h2>📡 Subscription Links</h2>
                <div class="flex">
                    <button class="btn" onclick="showQR()">📱 Show QR</button>
                    <button class="btn" onclick="copyLink()">📋 Copy Link</button>
                </div>
                <div id="qrContainer" style="display:none;margin-top:10px;">
                    <div style="background:white;padding:20px;border-radius:8px;display:inline-block;">
                        QR Code: <span id="qrText">https://${WORKER_NAME}.workers.dev/${API_ROUTE}/sub</span>
                    </div>
                </div>
                <div class="mt-10">
                    <input type="text" id="subLink" value="https://${WORKER_NAME}.workers.dev/${API_ROUTE}/sub" readonly>
                </div>
            </div>
            
            <div class="card">
                <h2>🌐 Network Info</h2>
                <p><strong>Status:</strong> <span class="status-badge status-online">● Online</span></p>
                <p><strong>Worker:</strong> ${WORKER_NAME}</p>
                <p><strong>Panel:</strong> ${PANEL_NAME}</p>
                <p><strong>Route:</strong> ${API_ROUTE}</p>
            </div>
        </div>
        
        <div class="card">
            <h2>⚙️ Settings</h2>
            <form onsubmit="updateSettings(event)">
                <div class="grid-2">
                    <div>
                        <label>Protocol</label>
                        <select id="protocol">
                            <option value="both">Both</option>
                            <option value="vless">VLESS</option>
                            <option value="trojan">Trojan</option>
                        </select>
                    </div>
                    <div>
                        <label>Kill Switch</label>
                        <select id="killSwitch">
                            <option value="off">Disabled</option>
                            <option value="on">Enabled</option>
                        </select>
                    </div>
                </div>
                <button type="submit" class="btn">Update Settings</button>
            </form>
        </div>
        
        <div class="card">
            <h2>📊 Usage Statistics</h2>
            <table style="width:100%;border-collapse:collapse;">
                <thead>
                    <tr style="background:#f9fafb;">
                        <th style="padding:10px;text-align:left;">Metric</th>
                        <th style="padding:10px;text-align:left;">Value</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td style="padding:10px;">Total Requests</td><td style="padding:10px;">0</td></tr>
                    <tr><td style="padding:10px;">Active Users</td><td style="padding:10px;">0</td></tr>
                    <tr><td style="padding:10px;">Uptime</td><td style="padding:10px;">100%</td></tr>
                </tbody>
            </table>
        </div>
    </div>
    
    <script>
        function showQR() {
            const container = document.getElementById('qrContainer');
            container.style.display = container.style.display === 'none' ? 'block' : 'none';
        }
        
        async function copyLink() {
            try {
                const link = document.getElementById('subLink');
                await navigator.clipboard.writeText(link.value);
                alert('Copied!');
            } catch (e) {
                alert('Copy failed: ' + e.message);
            }
        }
        
        function logout() {
            document.cookie = 'auth=;path=/;max-age=0';
            window.location.href = '/${API_ROUTE}/dash';
        }
        
        async function updateSettings(e) {
            e.preventDefault();
            const data = {
                protocol: document.getElementById('protocol').value,
                killSwitch: document.getElementById('killSwitch').value
            };
            
            try {
                const response = await fetch('/api/settings', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                if (response.ok) {
                    alert('Settings updated successfully!');
                } else {
                    alert('Update failed!');
                }
            } catch (error) {
                alert('Error: ' + error.message);
            }
        }
    </script>
</body>
</html>
            `, {
                headers: { 'Content-Type': 'text/html;charset=utf-8' }
            });
        }
        
        // Subscription endpoint
        if (path === '/${API_ROUTE}/sub') {
            const config = `vless://example@example.com:443?security=tls#Leef`;
            return new Response(config, {
                headers: { 'Content-Type': 'text/plain;charset=utf-8' }
            });
        }
        
        // Default: camouflage
        return new Response('', {
            status: 302,
            headers: { 'Location': 'https://ubuntu.com' }
        });
    }
};
EOF

print_success "Worker code generated"

# ============================================================
# CREATE WRANGLER CONFIG
# ============================================================

print_step "Creating Wrangler configuration"

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

print_success "wrangler.toml created"

# ============================================================
# DEPLOY WORKER
# ============================================================

print_step "Deploying to Cloudflare Workers"

print_info "Deploying $WORKER_NAME..."

# Login to Wrangler (if needed)
wrangler login --api-token "$CF_API_TOKEN" --email "$CF_EMAIL"

# Deploy
DEPLOY_OUTPUT=$(wrangler deploy --yes 2>&1)

if [ $? -eq 0 ]; then
    print_success "Deployment successful!"
    
    # Extract worker URL
    WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -o "https://[^ ]*\.workers\.dev" | head -1)
    if [ -z "$WORKER_URL" ]; then
        WORKER_URL="https://$WORKER_NAME.workers.dev"
    fi
else
    print_error "Deployment failed"
    print_info "Error: $DEPLOY_OUTPUT"
    exit 1
fi

# ============================================================
# FINAL OUTPUT
# ============================================================

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
cat > deployment_info.txt << EOF
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

print_success "Deployment information saved to deployment_info.txt"

echo -e "\n${GREEN}${BOLD}Thank you for using Leef Panel! 🍂${NC}\n"
