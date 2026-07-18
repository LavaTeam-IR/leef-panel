#!/bin/bash

# ============================================================
# 🍂 Leef Deploy - Direct Cloudflare API
# Token-only authentication (no email needed)
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
echo "║        🍂 LEEF DEPLOY - TOKEN ONLY v3.0                 ║"
echo "║                                                          ║"
echo "║     Deploy to Cloudflare Workers with API Token only     ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# GET API TOKEN (NO EMAIL REQUIRED)
# ============================================================

echo -e "\n${YELLOW}Enter your Cloudflare API Token:${NC}"
echo -e "${YELLOW}(Get token from: https://dash.cloudflare.com/profile/api-tokens)${NC}"
echo -e "${YELLOW}Token needs: Workers Scripts:Edit, Account Settings:Read${NC}\n"

read -sp "API Token: " CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}✗ API Token is required${NC}"
    exit 1
fi

# ============================================================
# VERIFY TOKEN & GET ACCOUNT ID
# ============================================================

echo -e "\n${GREEN}▶${NC} Verifying token..."

# Get Account ID from token
ACCOUNT_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if token is valid
if echo "$ACCOUNT_RESPONSE" | grep -q '"success":false'; then
    echo -e "${RED}✗ Invalid API Token. Please check and try again.${NC}"
    exit 1
fi

# Extract first account ID
ACCOUNT_ID=$(echo "$ACCOUNT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Could not fetch Account ID. Check token permissions.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Account ID: $ACCOUNT_ID"

# ============================================================
# GET CONFIG
# ============================================================

echo -e "\n${YELLOW}Enter panel settings:${NC}\n"

read -p "Worker name (e.g., leef-panel): " WORKER_NAME
[ -z "$WORKER_NAME" ] && WORKER_NAME="leef-panel"

read -p "Panel name (e.g., MyPanel): " PANEL_NAME
[ -z "$PANEL_NAME" ] && PANEL_NAME="LeefPanel"

read -p "API route (e.g., secret123): " API_ROUTE
[ -z "$API_ROUTE" ] && API_ROUTE="sync"

read -sp "Master key (min 6 chars): " MASTER_KEY
echo ""
[ -z "$MASTER_KEY" ] && MASTER_KEY="admin123"

# ============================================================
# DOWNLOAD OR GENERATE WORKER CODE
# ============================================================

echo -e "\n${GREEN}▶${NC} Preparing worker code..."

# Try to download from GitHub
REPO_URL="https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/_worker.js"
WORKER_RAW=$(curl -sSL "$REPO_URL" 2>/dev/null)

if [ -z "$WORKER_RAW" ] || echo "$WORKER_RAW" | grep -q "404: Not Found"; then
    echo -e "${YELLOW}⚠${NC} _worker.js not found in repository, using built-in code..."
    
    # Built-in worker code
    WORKER_RAW='// ============================================================
// 🍂leef - Cloudflare Worker Panel (Built-in)
// ============================================================

function getLoginHTML(route) {
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
            font-family: system-ui, sans-serif;
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
            max-width: 400px;
            width: 100%;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { font-size: 32px; color: #dc2626; }
        .header p { color: #6b7280; font-size: 14px; }
        input {
            width: 100%;
            padding: 12px;
            border: 2px solid #e5e7eb;
            border-radius: 8px;
            font-size: 16px;
            margin-bottom: 15px;
        }
        input:focus { outline: none; border-color: #dc2626; }
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
        }
        .btn:hover { background: #b91c1c; }
        .error { color: #dc2626; margin-top: 10px; display: none; }
        .footer { text-align: center; margin-top: 20px; color: #9ca3af; font-size: 13px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🍂 Leef</h1>
            <p>Enter your master key</p>
        </div>
        <form onsubmit="authenticate(event)">
            <input type="password" id="masterKey" placeholder="Master key..." required>
            <button type="submit" class="btn">Authenticate</button>
            <div id="error" class="error">Invalid master key</div>
        </form>
        <div class="footer">🍂 Leef Panel v3.0</div>
    </div>
    <script>
        async function authenticate(e) {
            e.preventDefault();
            const key = document.getElementById("masterKey").value;
            try {
                const res = await fetch("/api/auth", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ key })
                });
                if (res.ok) {
                    const data = await res.json();
                    document.cookie = "auth=" + data.token + ";path=/;max-age=86400";
                    window.location.href = "/${route}/dashboard";
                } else {
                    document.getElementById("error").style.display = "block";
                }
            } catch(e) {
                document.getElementById("error").style.display = "block";
            }
        }
    </script>
</body>
</html>
    `;
}

function getDashboardHTML(panelName, workerName, route) {
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🍂 ${panelName}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: system-ui, sans-serif;
            background: #f3f4f6;
            padding: 20px;
        }
        .container { max-width: 1000px; margin: 0 auto; }
        .header {
            background: linear-gradient(135deg, #dc2626, #991b1b);
            color: white;
            padding: 20px 30px;
            border-radius: 16px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
        }
        .header h1 { font-size: 24px; }
        .btn {
            padding: 8px 16px;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
        }
        .btn-white { background: white; color: #dc2626; }
        .btn-red { background: #dc2626; color: white; }
        .btn-red:hover { background: #b91c1c; }
        .card {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .card h2 { color: #dc2626; margin-bottom: 15px; font-size: 18px; }
        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        @media (max-width: 600px) { .grid-2 { grid-template-columns: 1fr; } }
        .badge-online {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            background: #dcfce7;
            color: #166534;
        }
        input, select {
            width: 100%;
            padding: 10px;
            border: 1px solid #d1d5db;
            border-radius: 8px;
            margin-bottom: 10px;
        }
        .flex { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
        .text-gray { color: #6b7280; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🍂 ${panelName}</h1>
            <div>
                <span class="badge-online">● Active</span>
                <button class="btn btn-white" onclick="logout()">Logout</button>
            </div>
        </div>
        
        <div class="grid-2">
            <div class="card">
                <h2>📡 Subscription</h2>
                <div class="flex">
                    <button class="btn btn-red" onclick="copyLink()">📋 Copy Link</button>
                </div>
                <input type="text" id="subLink" value="https://${workerName}.workers.dev/${route}/sub" readonly>
            </div>
            <div class="card">
                <h2>🌐 Info</h2>
                <p><strong>Worker:</strong> ${workerName}</p>
                <p><strong>Panel:</strong> ${panelName}</p>
                <p><strong>Route:</strong> ${route}</p>
            </div>
        </div>
        
        <div class="card">
            <h2>⚙️ Settings</h2>
            <form onsubmit="updateSettings(event)">
                <div class="grid-2">
                    <div>
                        <label class="text-gray">Protocol</label>
                        <select id="protocol">
                            <option value="both">Both</option>
                            <option value="vless">VLESS</option>
                            <option value="trojan">Trojan</option>
                        </select>
                    </div>
                    <div>
                        <label class="text-gray">Clean IPs</label>
                        <input type="text" id="cleanIPs" value="1.1.1.1,1.0.0.1">
                    </div>
                </div>
                <button type="submit" class="btn btn-red" style="width:100%;">Update</button>
            </form>
        </div>
    </div>
    <script>
        async function copyLink() {
            const link = document.getElementById("subLink").value;
            await navigator.clipboard.writeText(link);
            alert("Copied!");
        }
        function logout() {
            document.cookie = "auth=;path=/;max-age=0";
            window.location.href = "/${route}/dash";
        }
        async function updateSettings(e) {
            e.preventDefault();
            const data = {
                protocol: document.getElementById("protocol").value,
                cleanIPs: document.getElementById("cleanIPs").value.split(",").map(s => s.trim())
            };
            const res = await fetch("/api/config", {
                method: "PUT",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(data)
            });
            if (res.ok) alert("Settings updated!");
            else alert("Update failed!");
        }
    </script>
</body>
</html>
    `;
}

export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const path = url.pathname;
        const ROUTE = "API_ROUTE_PLACEHOLDER";
        const KEY = "MASTER_KEY_PLACEHOLDER";
        const PANEL = "PANEL_NAME_PLACEHOLDER";
        const WORKER = "WORKER_NAME_PLACEHOLDER";

        if (path === "/" || path === `/${ROUTE}/dash`) {
            return new Response(getLoginHTML(ROUTE), {
                headers: { "Content-Type": "text/html;charset=utf-8" }
            });
        }

        if (path === "/api/auth" && request.method === "POST") {
            const data = await request.json();
            if (data.key === KEY) {
                return new Response(JSON.stringify({ 
                    success: true, 
                    token: btoa(Date.now() + ":" + Math.random())
                }), {
                    headers: { "Content-Type": "application/json" }
                });
            }
            return new Response(JSON.stringify({ success: false }), { status: 401 });
        }

        if (path === `/${ROUTE}/dashboard`) {
            const cookies = request.headers.get("Cookie") || "";
            if (!cookies.includes("auth=")) {
                return Response.redirect(`/${ROUTE}/dash`, 302);
            }
            return new Response(getDashboardHTML(PANEL, WORKER, ROUTE), {
                headers: { "Content-Type": "text/html;charset=utf-8" }
            });
        }

        if (path === `/${ROUTE}/sub`) {
            const uuid = url.searchParams.get("sub") || "default-uuid";
            return new Response(
                `vless://${uuid}@1.1.1.1:443?security=tls&sni=gateway.leef.workers.dev#Leef`,
                { headers: { "Content-Type": "text/plain" } }
            );
        }

        if (path === "/api/config" && request.method === "PUT") {
            try {
                await request.json();
                return new Response(JSON.stringify({ success: true }), {
                    headers: { "Content-Type": "application/json" }
                });
            } catch(e) {
                return new Response(JSON.stringify({ error: e.message }), { status: 400 });
            }
        }

        return new Response("", {
            status: 302,
            headers: { "Location": "https://ubuntu.com" }
        });
    }
};
'
fi

# Replace placeholders
WORKER_CODE=$(echo "$WORKER_RAW" | sed "s/MASTER_KEY_PLACEHOLDER/$MASTER_KEY/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/PANEL_NAME_PLACEHOLDER/$PANEL_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s/WORKER_NAME_PLACEHOLDER/$WORKER_NAME/g")
WORKER_CODE=$(echo "$WORKER_CODE" | sed "s|API_ROUTE_PLACEHOLDER|$API_ROUTE|g")

echo -e "${GREEN}✓${NC} Worker code ready"

# ============================================================
# DEPLOY VIA API
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
    ERROR_MSG=$(echo "$DEPLOY_RESPONSE" | grep -o '"msg":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$ERROR_MSG" ]; then
        echo -e "${RED}Error: $ERROR_MSG${NC}"
    fi
    exit 1
fi

# ============================================================
# FINAL OUTPUT
# ============================================================

clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║           ✅ DEPLOYMENT COMPLETE!                        ║"
echo "║                                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "\n${GREEN}${BOLD}📋 Your Leef Panel Details:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${GREEN}▶${NC} Panel Name: ${BOLD}$PANEL_NAME${NC}"
echo -e "${GREEN}▶${NC} Dashboard URL: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/dash${NC}"
echo -e "${GREEN}▶${NC} Subscription URL: ${YELLOW}https://$WORKER_NAME.workers.dev/$API_ROUTE/sub${NC}"
echo -e "${GREEN}▶${NC} Master Key: ${YELLOW}$MASTER_KEY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Save info
cat > leef_info.txt << EOF
=============================================
🍂 LEEF PANEL DEPLOYMENT INFORMATION
=============================================
Dashboard: https://$WORKER_NAME.workers.dev/$API_ROUTE/dash
Subscription: https://$WORKER_NAME.workers.dev/$API_ROUTE/sub
Master Key: $MASTER_KEY
Panel Name: $PANEL_NAME
Worker Name: $WORKER_NAME
=============================================
EOF

echo -e "\n${GREEN}✓${NC} Info saved to leef_info.txt"
echo -e "\n${GREEN}${BOLD}Thank you! 🍂${NC}\n"
