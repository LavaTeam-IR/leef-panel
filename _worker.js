// ============================================================
// 🍂leef - Cloudflare Worker Panel
// Version: 3.0.0
// Description: Full-featured V2Ray panel on Cloudflare Workers
// ============================================================

// ----- Configuration -----
const CONFIG = {
    APP_NAME: '🍂leef',
    VERSION: '3.0.0',
    DEFAULT_ROUTE: 'sync',
    DEFAULT_MASTER_KEY: 'admin123',
    DEFAULT_CAMOUFLAGE: 'https://ubuntu.com',
    PROTOCOLS: ['vless', 'trojan']
};

// ----- Database Handler (D1) -----
class DatabaseHandler {
    constructor(env) {
        this.env = env;
        this.db = env.IOT_DB;
    }

    async get(key) {
        try {
            const result = await this.db.prepare('SELECT value FROM kv_store WHERE key = ?').bind(key).first();
            return result ? JSON.parse(result.value) : null;
        } catch (e) {
            console.error('DB get error:', e);
            return null;
        }
    }

    async set(key, value) {
        try {
            await this.db.prepare('INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)').bind(key, JSON.stringify(value)).run();
            return true;
        } catch (e) {
            console.error('DB set error:', e);
            return false;
        }
    }

    async delete(key) {
        try {
            await this.db.prepare('DELETE FROM kv_store WHERE key = ?').bind(key).run();
            return true;
        } catch (e) {
            console.error('DB delete error:', e);
            return false;
        }
    }

    async init() {
        try {
            await this.db.prepare('CREATE TABLE IF NOT EXISTS kv_store (key TEXT PRIMARY KEY, value TEXT)').run();
            
            // Set default config if not exists
            const config = await this.get('config');
            if (!config) {
                const defaultConfig = {
                    route: this.env.API_ROUTE || CONFIG.DEFAULT_ROUTE,
                    deviceUUID: this.generateUUID(),
                    protocol: 'both',
                    cleanIPs: ['1.1.1.1', '1.0.0.1'],
                    multiUsers: [],
                    telegramBotToken: '',
                    telegramChatId: '',
                    killSwitch: false,
                    ech: false,
                    camouflageUrl: CONFIG.DEFAULT_CAMOUFLAGE,
                    lastUpdated: new Date().toISOString()
                };
                await this.set('config', defaultConfig);
            }
            
            // Set master key if not exists
            const masterKey = await this.get('masterKey');
            if (!masterKey) {
                await this.set('masterKey', this.env.MASTER_KEY || CONFIG.DEFAULT_MASTER_KEY);
            }
            
            return true;
        } catch (e) {
            console.error('DB init error:', e);
            return false;
        }
    }

    generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }
}

// ----- Main Worker -----
export default {
    async fetch(request, env) {
        try {
            const url = new URL(request.url);
            const path = url.pathname;
            
            // Initialize DB
            const db = new DatabaseHandler(env);
            await db.init();
            
            // Get config
            const config = await db.get('config');
            if (!config) {
                return new Response('Configuration error', { status: 500 });
            }
            
            // Check kill switch
            if (config.killSwitch) {
                return new Response('Service temporarily unavailable', { 
                    status: 503,
                    headers: { 'Content-Type': 'text/plain' }
                });
            }
            
            const ROUTE = config.route || CONFIG.DEFAULT_ROUTE;
            const MASTER_KEY = await db.get('masterKey') || CONFIG.DEFAULT_MASTER_KEY;
            
            // ----- ROUTE: Dashboard Login -----
            if (path === `/${ROUTE}/dash` || path === `/${ROUTE}`) {
                return new Response(generateLoginHTML(ROUTE), {
                    headers: { 'Content-Type': 'text/html;charset=utf-8' }
                });
            }
            
            // ----- ROUTE: Authentication API -----
            if (path === '/api/auth' && request.method === 'POST') {
                try {
                    const data = await request.json();
                    if (data.key === MASTER_KEY) {
                        const token = btoa(Date.now() + ':' + Math.random());
                        return new Response(JSON.stringify({ 
                            success: true, 
                            token: token,
                            redirect: `/${ROUTE}/dashboard`
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
                    return new Response(JSON.stringify({ success: false }), { 
                        status: 400,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
            }
            
            // ----- ROUTE: Dashboard (Protected) -----
            if (path === `/${ROUTE}/dashboard`) {
                // Check auth
                const cookies = request.headers.get('Cookie') || '';
                if (!cookies.includes('auth=')) {
                    return Response.redirect(`/${ROUTE}/dash`, 302);
                }
                
                const panelName = env.PANEL_NAME || 'Leef Panel';
                const workerName = env.WORKER_NAME || 'leef-panel';
                const protocol = config.protocol || 'both';
                
                return new Response(generateDashboardHTML(ROUTE, panelName, workerName, MASTER_KEY, protocol), {
                    headers: { 'Content-Type': 'text/html;charset=utf-8' }
                });
            }
            
            // ----- ROUTE: Get Config (API) -----
            if (path === '/api/config' && request.method === 'GET') {
                // Check auth
                const cookies = request.headers.get('Cookie') || '';
                if (!cookies.includes('auth=')) {
                    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
                        status: 401,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
                
                const configData = await db.get('config');
                return new Response(JSON.stringify(configData), {
                    headers: { 'Content-Type': 'application/json' }
                });
            }
            
            // ----- ROUTE: Update Config (API) -----
            if (path === '/api/config' && request.method === 'PUT') {
                // Check auth
                const cookies = request.headers.get('Cookie') || '';
                if (!cookies.includes('auth=')) {
                    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
                        status: 401,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
                
                try {
                    const data = await request.json();
                    const currentConfig = await db.get('config');
                    const updatedConfig = { ...currentConfig, ...data, lastUpdated: new Date().toISOString() };
                    await db.set('config', updatedConfig);
                    
                    return new Response(JSON.stringify({ success: true }), {
                        headers: { 'Content-Type': 'application/json' }
                    });
                } catch (e) {
                    return new Response(JSON.stringify({ error: e.message }), { 
                        status: 400,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
            }
            
            // ----- ROUTE: Update Master Key (API) -----
            if (path === '/api/masterkey' && request.method === 'PUT') {
                // Check auth
                const cookies = request.headers.get('Cookie') || '';
                if (!cookies.includes('auth=')) {
                    return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
                        status: 401,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
                
                try {
                    const data = await request.json();
                    if (!data.newKey || data.newKey.length < 6) {
                        return new Response(JSON.stringify({ error: 'Key must be at least 6 characters' }), { 
                            status: 400,
                            headers: { 'Content-Type': 'application/json' }
                        });
                    }
                    
                    await db.set('masterKey', data.newKey);
                    return new Response(JSON.stringify({ success: true }), {
                        headers: { 'Content-Type': 'application/json' }
                    });
                } catch (e) {
                    return new Response(JSON.stringify({ error: e.message }), { 
                        status: 400,
                        headers: { 'Content-Type': 'application/json' }
                    });
                }
            }
            
            // ----- ROUTE: Subscription -----
            if (path === `/${ROUTE}/sub`) {
                const userUUID = url.searchParams.get('sub') || config.deviceUUID;
                
                // Generate VLESS config
                const cleanIPs = config.cleanIPs || ['1.1.1.1'];
                const host = config.host || 'gateway.leef.workers.dev';
                const protocol = config.protocol || 'both';
                
                let entries = [];
                
                for (const ip of cleanIPs) {
                    if (protocol === 'both' || protocol === 'vless') {
                        const vlessStr = `vless://${userUUID}@${ip}:443?encryption=none&security=tls&sni=${host}&fp=randomized&alpn=h2,http/1.1&type=ws&host=${host}&path=/#${CONFIG.APP_NAME}%20-%20VLESS%20(${ip})`;
                        entries.push(vlessStr);
                    }
                    
                    if (protocol === 'both' || protocol === 'trojan') {
                        const trojanStr = `trojan://${userUUID}@${ip}:443?security=tls&sni=${host}&fp=randomized&alpn=h2,http/1.1&type=ws&host=${host}&path=/#${CONFIG.APP_NAME}%20-%20Trojan%20(${ip})`;
                        entries.push(trojanStr);
                    }
                }
                
                return new Response(entries.join('\n'), {
                    headers: { 'Content-Type': 'text/plain;charset=utf-8' }
                });
            }
            
            // ----- ROUTE: Camouflage (Default) -----
            return new Response('', {
                status: 302,
                headers: { 'Location': config.camouflageUrl || CONFIG.DEFAULT_CAMOUFLAGE }
            });
            
        } catch (e) {
            console.error('Worker error:', e);
            return new Response('Internal Server Error: ' + e.message, { 
                status: 500,
                headers: { 'Content-Type': 'text/plain' }
            });
        }
    }
};

// ============================================================
// HTML GENERATORS
// ============================================================

function generateLoginHTML(route) {
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
            max-width: 420px;
            width: 100%;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 32px;
            color: #dc2626;
        }
        .header p {
            color: #6b7280;
            margin-top: 5px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            font-weight: 600;
            margin-bottom: 8px;
            color: #374151;
            font-size: 14px;
        }
        input {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e5e7eb;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.2s;
        }
        input:focus {
            outline: none;
            border-color: #dc2626;
            box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
        }
        .btn {
            width: 100%;
            padding: 14px;
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
        .btn:active {
            transform: scale(0.98);
        }
        .error {
            color: #dc2626;
            font-size: 14px;
            margin-top: 12px;
            display: none;
            text-align: center;
        }
        .footer {
            text-align: center;
            margin-top: 24px;
            color: #9ca3af;
            font-size: 13px;
        }
        .footer span {
            color: #dc2626;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🍂 Leef</h1>
            <p>Enter your master key to access the panel</p>
        </div>
        <form onsubmit="authenticate(event)">
            <div class="form-group">
                <label for="masterKey">Master Key</label>
                <input type="password" id="masterKey" placeholder="Enter master key..." required autofocus>
            </div>
            <button type="submit" class="btn">🔑 Authenticate</button>
            <div id="error" class="error">❌ Invalid master key. Please try again.</div>
        </form>
        <div class="footer">
            🍂 <span>Leef Panel</span> v3.0
        </div>
    </div>
    <script>
        async function authenticate(e) {
            e.preventDefault();
            const key = document.getElementById('masterKey').value;
            const errorEl = document.getElementById('error');
            
            if (!key) {
                errorEl.textContent = '❌ Please enter your master key';
                errorEl.style.display = 'block';
                return;
            }
            
            try {
                const response = await fetch('/api/auth', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ key: key })
                });
                
                if (response.ok) {
                    const data = await response.json();
                    document.cookie = 'auth=' + data.token + ';path=/;max-age=86400';
                    window.location.href = data.redirect || '/${route}/dashboard';
                } else {
                    errorEl.textContent = '❌ Invalid master key';
                    errorEl.style.display = 'block';
                    document.getElementById('masterKey').value = '';
                    document.getElementById('masterKey').focus();
                }
            } catch (error) {
                errorEl.textContent = '❌ Connection error. Please try again.';
                errorEl.style.display = 'block';
            }
        }
        
        // Enter key support
        document.getElementById('masterKey').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                document.querySelector('form').onsubmit();
            }
        });
    </script>
</body>
</html>
    `;
}

function generateDashboardHTML(route, panelName, workerName, masterKey, protocol) {
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🍂 ${panelName} - Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: system-ui, -apple-system, sans-serif;
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
            padding: 24px 32px;
            border-radius: 16px;
            margin-bottom: 30px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 15px;
        }
        .header h1 {
            font-size: 26px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .header h1 span {
            background: rgba(255,255,255,0.2);
            padding: 2px 12px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 400;
        }
        .header-actions {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .btn {
            padding: 8px 18px;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            font-size: 14px;
        }
        .btn-white {
            background: white;
            color: #dc2626;
        }
        .btn-white:hover {
            background: #fef2f2;
            transform: translateY(-1px);
        }
        .btn-red {
            background: #dc2626;
            color: white;
        }
        .btn-red:hover {
            background: #b91c1c;
            transform: translateY(-1px);
        }
        .btn-outline {
            background: transparent;
            color: white;
            border: 2px solid rgba(255,255,255,0.3);
        }
        .btn-outline:hover {
            background: rgba(255,255,255,0.1);
        }
        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        @media (max-width: 768px) {
            .grid-2 {
                grid-template-columns: 1fr;
            }
        }
        .card {
            background: white;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .card h2 {
            color: #dc2626;
            font-size: 18px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .card h2 .badge {
            background: #fef2f2;
            color: #dc2626;
            padding: 2px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 500;
        }
        .status-badge {
            display: inline-block;
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
        }
        .status-online {
            background: #dcfce7;
            color: #166534;
        }
        .status-offline {
            background: #fee2e2;
            color: #991b1b;
        }
        .flex {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            align-items: center;
        }
        .flex-between {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
        }
        .mt-10 { margin-top: 10px; }
        .mb-10 { margin-bottom: 10px; }
        input, select {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid #d1d5db;
            border-radius: 8px;
            font-size: 14px;
            margin-bottom: 10px;
            transition: border-color 0.2s;
        }
        input:focus, select:focus {
            outline: none;
            border-color: #dc2626;
            box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
        }
        .copy-btn {
            background: #f3f4f6;
            border: 1px solid #d1d5db;
            padding: 4px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }
        .copy-btn:hover {
            background: #e5e7eb;
        }
        .toast {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #1f2937;
            color: white;
            padding: 12px 24px;
            border-radius: 8px;
            opacity: 0;
            transition: opacity 0.3s;
            pointer-events: none;
            z-index: 999;
        }
        .toast.show {
            opacity: 1;
        }
        .text-red { color: #dc2626; }
        .text-gray { color: #6b7280; }
        .text-sm { font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>
                🍂 ${panelName}
                <span>v3.0</span>
            </h1>
            <div class="header-actions">
                <span class="status-badge status-online">● Active</span>
                <button class="btn btn-white" onclick="logout()">🚪 Logout</button>
            </div>
        </div>

        <!-- Grid -->
        <div class="grid-2">
            <!-- Subscription Card -->
            <div class="card">
                <h2>📡 Subscription Links</h2>
                <div class="flex mb-10">
                    <button class="btn btn-red" onclick="showQR()">📱 Show QR</button>
                    <button class="btn btn-red" onclick="copyLink()">📋 Copy Link</button>
                </div>
                <div id="qrContainer" style="display:none;margin-bottom:10px;">
                    <div style="background:#f9fafb;padding:20px;border-radius:8px;text-align:center;">
                        <span style="font-size:14px;color:#6b7280;">Scan this QR code in your client</span>
                        <div style="margin:10px 0;font-size:12px;word-break:break-all;" id="qrText">
                            https://${workerName}.workers.dev/${route}/sub
                        </div>
                    </div>
                </div>
                <label class="text-sm text-gray">Subscription URL:</label>
                <div class="flex">
                    <input type="text" id="subLink" value="https://${workerName}.workers.dev/${route}/sub" readonly style="flex:1;">
                    <button class="copy-btn" onclick="copySubLink()">📋 Copy</button>
                </div>
                <div class="mt-10">
                    <label class="text-sm text-gray">Protocol:</label>
                    <span style="font-weight:600;">${protocol.toUpperCase()}</span>
                </div>
            </div>

            <!-- Network Info -->
            <div class="card">
                <h2>🌐 Network Info</h2>
                <div style="display:grid;gap:8px;">
                    <div><strong>Status:</strong> <span class="status-badge status-online">● Online</span></div>
                    <div><strong>Worker:</strong> ${workerName}</div>
                    <div><strong>Panel:</strong> ${panelName}</div>
                    <div><strong>Route:</strong> ${route}</div>
                    <div><strong>Master Key:</strong> <span style="font-family:monospace;font-size:13px;">${masterKey}</span></div>
                </div>
            </div>
        </div>

        <!-- Settings -->
        <div class="card">
            <h2>⚙️ Settings</h2>
            <form onsubmit="updateSettings(event)">
                <div class="grid-2">
                    <div>
                        <label class="text-sm text-gray">Protocol</label>
                        <select id="protocol">
                            <option value="both" ${protocol === 'both' ? 'selected' : ''}>Both</option>
                            <option value="vless" ${protocol === 'vless' ? 'selected' : ''}>VLESS</option>
                            <option value="trojan" ${protocol === 'trojan' ? 'selected' : ''}>Trojan</option>
                        </select>
                    </div>
                    <div>
                        <label class="text-sm text-gray">Kill Switch</label>
                        <select id="killSwitch">
                            <option value="false">Disabled</option>
                            <option value="true">Enabled</option>
                        </select>
                    </div>
                </div>
                <div class="grid-2">
                    <div>
                        <label class="text-sm text-gray">Clean IPs (one per line)</label>
                        <textarea id="cleanIPs" rows="3" style="width:100%;padding:10px;border:1px solid #d1d5db;border-radius:8px;">1.1.1.1
1.0.0.1</textarea>
                    </div>
                    <div>
                        <label class="text-sm text-gray">Master Key (min 6 chars)</label>
                        <input type="password" id="newMasterKey" placeholder="Change master key...">
                    </div>
                </div>
                <button type="submit" class="btn btn-red" style="width:100%;padding:12px;">💾 Update Settings</button>
            </form>
        </div>

        <!-- Usage -->
        <div class="card">
            <h2>📊 Usage Statistics</h2>
            <table style="width:100%;border-collapse:collapse;">
                <thead>
                    <tr style="background:#f9fafb;">
                        <th style="padding:10px;text-align:left;">Metric</th>
                        <th style="padding:10px;text-align:right;">Value</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td style="padding:10px;">Total Configs Generated</td><td style="padding:10px;text-align:right;">0</td></tr>
                    <tr><td style="padding:10px;">Active Users</td><td style="padding:10px;text-align:right;">0</td></tr>
                    <tr><td style="padding:10px;">Uptime</td><td style="padding:10px;text-align:right;">100%</td></tr>
                    <tr><td style="padding:10px;">Clean IPs</td><td style="padding:10px;text-align:right;">2</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Toast -->
    <div id="toast" class="toast"></div>

    <script>
        // Show toast
        function showToast(msg) {
            const toast = document.getElementById('toast');
            toast.textContent = msg;
            toast.classList.add('show');
            setTimeout(() => toast.classList.remove('show'), 3000);
        }

        // Copy link
        function copyLink() {
            const link = document.getElementById('subLink').value;
            navigator.clipboard.writeText(link).then(() => {
                showToast('✅ Subscription link copied!');
            }).catch(() => {
                showToast('❌ Copy failed. Please select and copy manually.');
            });
        }

        function copySubLink() {
            copyLink();
        }

        // QR
        function showQR() {
            const container = document.getElementById('qrContainer');
            container.style.display = container.style.display === 'none' ? 'block' : 'none';
        }

        // Update settings
        async function updateSettings(e) {
            e.preventDefault();
            
            const data = {
                protocol: document.getElementById('protocol').value,
                killSwitch: document.getElementById('killSwitch').value === 'true',
                cleanIPs: document.getElementById('cleanIPs').value.split('\\n').filter(Boolean)
            };
            
            const newKey = document.getElementById('newMasterKey').value;
            
            try {
                // Update config
                const configRes = await fetch('/api/config', {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                if (!configRes.ok) {
                    throw new Error('Failed to update config');
                }
                
                // Update master key if provided
                if (newKey && newKey.length >= 6) {
                    const keyRes = await fetch('/api/masterkey', {
                        method: 'PUT',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ newKey: newKey })
                    });
                    
                    if (!keyRes.ok) {
                        showToast('⚠️ Config saved but master key update failed');
                    } else {
                        showToast('✅ Master key updated!');
                    }
                }
                
                showToast('✅ Settings updated successfully!');
                
                // Reload config
                setTimeout(() => location.reload(), 1000);
                
            } catch (error) {
                showToast('❌ Error: ' + error.message);
            }
        }

        // Logout
        function logout() {
            document.cookie = 'auth=;path=/;max-age=0';
            window.location.href = '/${route}/dash';
        }
    </script>
</body>
</html>
    `;
}
