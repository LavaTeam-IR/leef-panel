#!/bin/bash

# 🍂 Leef Panel - Termux Auto Installer
# Developed by LavaTeam-IR
# GitHub: https://github.com/LavaTeam-IR

clear
echo "🍂 Leef Panel Installer"
echo "========================"
echo ""

# Check if running in Termux
if [ ! -d "$PREFIX" ]; then
    echo "❌ This script is for Termux only!"
    exit 1
fi

# Update packages
echo "📦 Updating packages..."
pkg update -y && pkg upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."
pkg install -y nodejs-lts python git wget curl

# Check Node.js
NODE_VERSION=$(node -v 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
if [ -z "$NODE_VERSION" ] || [ $NODE_VERSION -lt 18 ]; then
    echo "⚠️  Installing Node.js 18+..."
    pkg install -y nodejs-lts
fi

# Get admin password
echo ""
echo "🔐 Enter admin panel password:"
read -s ADMIN_PASS
echo ""

# Create directory
mkdir -p ~/leef
cd ~/leef

# Create package.json
cat > package.json << 'EOF'
{
  "name": "leef-panel",
  "version": "1.0.0",
  "description": "🍂 Leef Panel - Modern Admin Dashboard",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "sqlite3": "^5.1.6",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3"
  }
}
EOF

# Create server.js
cat > server.js << 'EOF'
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const fs = require('fs');

const app = express();
const PORT = 3000;
const JWT_SECRET = 'leef-panel-2024-secret';

app.use(cors());
app.use(express.json());

// Database
const db = new sqlite3.Database('./leef.db');

// Create tables
db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE,
      password TEXT,
      email TEXT,
      role TEXT DEFAULT 'user',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_login DATETIME
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      action TEXT,
      details TEXT,
      ip TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);
});

// Auth middleware
const auth = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    jwt.verify(token, JWT_SECRET);
    next();
  } catch(e) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// HTML Page
const html = `
<!DOCTYPE html>
<html dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🍂 Leef Panel</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    * { font-family: system-ui, -apple-system, sans-serif; }
    body { background: #0d1117; color: #c9d1d9; margin: 0; }
    .card { background: #161b22; border-radius: 12px; padding: 20px; border: 1px solid #30363d; }
    .btn { background: #238636; padding: 10px 20px; border-radius: 8px; border: none; color: #fff; cursor: pointer; font-weight: 600; }
    .btn:hover { background: #2ea043; }
    .btn-danger { background: #da3633; }
    .btn-danger:hover { background: #f85149; }
    input { background: #0d1117; border: 1px solid #30363d; padding: 10px; border-radius: 8px; color: #fff; width: 100%; box-sizing: border-box; }
    .sidebar { background: #161b22; padding: 20px; height: 100vh; position: fixed; width: 220px; border-right: 1px solid #30363d; }
    .main { margin-left: 240px; padding: 20px; }
    .nav-item { padding: 10px 12px; cursor: pointer; border-radius: 8px; margin-bottom: 4px; transition: 0.2s; }
    .nav-item:hover { background: #30363d; }
    .nav-item.active { background: #238636; }
    .hidden { display: none !important; }
    .flex-center { display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    .w-96 { max-width: 400px; width: 100%; }
    .text-green { color: #238636; }
    .text-red { color: #f85149; }
    .text-gray { color: #8b949e; }
    .border-b { border-bottom: 1px solid #30363d; }
    .p-2 { padding: 8px; }
    .py-1 { padding-top: 4px; padding-bottom: 4px; }
    .mt-2 { margin-top: 8px; }
    .mt-4 { margin-top: 16px; }
    .mb-4 { margin-bottom: 16px; }
    .gap-2 { gap: 8px; }
    .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
    @media (max-width: 768px) { .grid-3 { grid-template-columns: 1fr; } .sidebar { width: 60px; padding: 10px; } .sidebar span { display: none; } .main { margin-left: 70px; } }
  </style>
</head>
<body>

<!-- Login -->
<div id="loginPage" class="flex-center">
  <div class="card w-96">
    <h1 class="text-2xl font-bold mb-2">🍂 Leef Panel</h1>
    <p class="text-gray mb-4">Sign in to your dashboard</p>
    <input id="username" placeholder="Username" class="mb-3" value="admin">
    <input id="password" type="password" placeholder="Password" class="mb-3">
    <button onclick="login()" class="btn w-full">Sign In</button>
    <div id="errorMsg" class="text-red mt-2 hidden">Invalid credentials</div>
  </div>
</div>

<!-- Dashboard -->
<div id="dashboardPage" class="hidden">
  <div class="sidebar">
    <h2 class="text-xl font-bold mb-6">🍂 Leef</h2>
    <div class="nav-item active" onclick="showPage('dashboard')">📊 <span>Dashboard</span></div>
    <div class="nav-item" onclick="showPage('users')">👥 <span>Users</span></div>
    <div class="nav-item" onclick="showPage('logs')">📝 <span>Logs</span></div>
    <div class="nav-item" style="color:#f85149;margin-top:20px;" onclick="logout()">🚪 <span>Logout</span></div>
    <div style="position:absolute;bottom:20px;font-size:11px;color:#8b949e;">LavaTeam-IR</div>
  </div>

  <div class="main">
    <!-- Dashboard -->
    <div id="page-dashboard">
      <h2 class="text-2xl font-bold mb-2">Dashboard</h2>
      <p class="text-gray mb-4">System overview</p>
      <div class="grid-3 mb-4">
        <div class="card"><div class="text-gray text-sm">Total Users</div><div class="text-3xl font-bold" id="statUsers">0</div></div>
        <div class="card"><div class="text-gray text-sm">Total Logs</div><div class="text-3xl font-bold" id="statLogs">0</div></div>
        <div class="card"><div class="text-gray text-sm">Online Users</div><div class="text-3xl font-bold" id="statOnline">0</div></div>
      </div>
      <div class="card">
        <h3 class="font-bold mb-2">Recent Activity</h3>
        <div id="recentActivity"></div>
      </div>
    </div>

    <!-- Users -->
    <div id="page-users" class="hidden">
      <div class="flex justify-between items-center mb-4">
        <div><h2 class="text-2xl font-bold">Users</h2><p class="text-gray">Manage system users</p></div>
        <button onclick="createUser()" class="btn">+ New User</button>
      </div>
      <div class="card" id="userList"></div>
    </div>

    <!-- Logs -->
    <div id="page-logs" class="hidden">
      <div class="mb-4"><h2 class="text-2xl font-bold">Logs</h2><p class="text-gray">System activity logs</p></div>
      <div class="card" id="logList"></div>
    </div>
  </div>
</div>

<script>
let token = localStorage.getItem('token');
if (token) {
  document.getElementById('loginPage').classList.add('hidden');
  document.getElementById('dashboardPage').classList.remove('hidden');
  loadData();
}

async function login() {
  const username = document.getElementById('username').value;
  const password = document.getElementById('password').value;
  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const data = await res.json();
    if (!res.ok) throw new Error();
    localStorage.setItem('token', data.token);
    location.reload();
  } catch(e) {
    document.getElementById('errorMsg').classList.remove('hidden');
  }
}

function logout() {
  localStorage.removeItem('token');
  location.reload();
}

function showPage(page) {
  ['dashboard', 'users', 'logs'].forEach(p => {
    document.getElementById('page-' + p).classList.add('hidden');
  });
  document.getElementById('page-' + page).classList.remove('hidden');
  document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
  event.target.classList.add('active');
  if (page === 'users') loadUsers();
  if (page === 'logs') loadLogs();
}

async function loadData() {
  try {
    const res = await fetch('/api/stats', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    const data = await res.json();
    document.getElementById('statUsers').textContent = data.users || 0;
    document.getElementById('statLogs').textContent = data.logs || 0;
    document.getElementById('statOnline').textContent = data.active || 0;
  } catch(e) {}
  loadActivity();
}

async function loadActivity() {
  try {
    const res = await fetch('/api/logs?limit=5', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    const logs = await res.json();
    document.getElementById('recentActivity').innerHTML = logs.map(l => 
      `<div class="flex justify-between items-center py-1 border-b border-gray-800">
        <span>${l.username || 'System'}</span>
        <span class="text-gray text-sm">${l.action}</span>
        <span class="text-gray text-xs">${new Date(l.created_at).toLocaleString()}</span>
      </div>`
    ).join('') || '<div class="text-gray text-center py-4">No activity yet</div>';
  } catch(e) {}
}

async function loadUsers() {
  try {
    const res = await fetch('/api/users', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    const users = await res.json();
    document.getElementById('userList').innerHTML = users.map(u => `
      <div class="flex justify-between items-center p-2 border-b border-gray-800">
        <div>
          <span class="font-bold">${u.username}</span>
          <span class="text-gray text-sm ml-2">${u.email || ''}</span>
        </div>
        <div>
          <span class="text-xs px-2 py-1 bg-green-900 text-green rounded">${u.role}</span>
          ${u.username !== 'admin' ? `<button onclick="deleteUser(${u.id})" class="btn-danger text-xs ml-2 px-2 py-1 rounded" style="background:#da3633;border:none;color:#fff;cursor:pointer;">Delete</button>` : ''}
        </div>
      </div>
    `).join('');
  } catch(e) {}
}

async function loadLogs() {
  try {
    const res = await fetch('/api/logs', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    const logs = await res.json();
    document.getElementById('logList').innerHTML = logs.map(l => `
      <div class="flex justify-between items-center py-1 border-b border-gray-800">
        <span class="font-bold">${l.username || 'System'}</span>
        <span>${l.action}</span>
        <span class="text-gray text-xs">${new Date(l.created_at).toLocaleString()}</span>
      </div>
    `).join('') || '<div class="text-gray text-center py-4">No logs found</div>';
  } catch(e) {}
}

async function createUser() {
  const username = prompt('Enter username:');
  if (!username) return;
  const password = prompt('Enter password:');
  if (!password) return;
  const email = prompt('Enter email (optional):') || '';

  try {
    await fetch('/api/users', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + token
      },
      body: JSON.stringify({ username, password, email, role: 'user' })
    });
    loadUsers();
    loadData();
    alert('User created successfully!');
  } catch(e) {
    alert('Error creating user');
  }
}

async function deleteUser(id) {
  if (!confirm('Delete this user?')) return;
  try {
    await fetch('/api/users/' + id, {
      method: 'DELETE',
      headers: { 'Authorization': 'Bearer ' + token }
    });
    loadUsers();
    loadData();
  } catch(e) {
    alert('Error deleting user');
  }
}

setInterval(() => { if (token) loadData(); }, 30000);
</script>
</body>
</html>
`;

// API Routes
app.get('/', (req, res) => res.send(html));
app.get('/api/*', (req, res) => res.send(html));

// Login
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  db.get('SELECT * FROM users WHERE username = ?', [username], (err, user) => {
    if (err || !user) return res.status(401).json({ error: 'Invalid' });
    bcrypt.compare(password, user.password, (err, valid) => {
      if (!valid) return res.status(401).json({ error: 'Invalid' });
      const token = jwt.sign({ id: user.id, username: user.username }, JWT_SECRET, { expiresIn: '24h' });
      db.run('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?', [user.id]);
      res.json({ token, user: { id: user.id, username: user.username, role: user.role } });
    });
  });
});

// Stats
app.get('/api/stats', auth, (req, res) => {
  db.get('SELECT COUNT(*) as users FROM users', (e, u) => {
    db.get('SELECT COUNT(*) as logs FROM logs', (e, l) => {
      db.get("SELECT COUNT(*) as active FROM users WHERE last_login > datetime('now', '-1 day')", (e, a) => {
        res.json({ users: u?.users || 0, logs: l?.logs || 0, active: a?.active || 0 });
      });
    });
  });
});

// Users
app.get('/api/users', auth, (req, res) => {
  db.all('SELECT id, username, email, role FROM users', (err, users) => res.json(users));
});

app.post('/api/users', auth, (req, res) => {
  const { username, password, email, role } = req.body;
  bcrypt.hash(password, 10, (err, hash) => {
    db.run('INSERT INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
      [username, hash, email || '', role || 'user'],
      function(err) {
        if (err) return res.status(400).json({ error: 'Username exists' });
        res.json({ id: this.lastID });
      }
    );
  });
});

app.delete('/api/users/:id', auth, (req, res) => {
  if (parseInt(req.params.id) === 1) return res.status(400).json({ error: 'Cannot delete admin' });
  db.run('DELETE FROM users WHERE id = ?', [req.params.id], () => res.json({ ok: true }));
});

// Logs
app.get('/api/logs', auth, (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  db.all(
    `SELECT logs.*, users.username 
     FROM logs 
     LEFT JOIN users ON logs.user_id = users.id 
     ORDER BY logs.created_at DESC 
     LIMIT ?`,
    [limit],
    (err, logs) => res.json(logs)
  );
});

// Log activity
app.post('/api/log', (req, res) => {
  const { user_id, action, details, ip } = req.body;
  db.run('INSERT INTO logs (user_id, action, details, ip) VALUES (?, ?, ?, ?)',
    [user_id, action, details, ip],
    () => res.json({ ok: true })
  );
});

app.listen(PORT, () => {
  console.log('🍂 Leef Panel running on http://localhost:' + PORT);
});
EOF

# Install npm packages
echo "📦 Installing npm packages..."
npm install 2>/dev/null || {
  echo "⚠️  npm failed, trying with --force..."
  npm install --force 2>/dev/null || {
    echo "❌ npm install failed, trying alternative..."
    npm install express sqlite3 bcryptjs jsonwebtoken cors --save 2>/dev/null
  }
}

# Create admin user
echo "👤 Creating admin user..."
node -e "
const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcryptjs');
const db = new sqlite3.Database('./leef.db');
const hash = bcrypt.hashSync('$ADMIN_PASS', 10);
db.run('INSERT OR IGNORE INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
  ['admin', hash, 'admin@leef.local', 'admin'],
  function(err) {
    if (err) console.error('Error:', err);
    else console.log('✅ Admin user created');
    db.close();
  }
);
"

# Start server
echo "🚀 Starting Leef Panel..."
node server.js &
SERVER_PID=$!
sleep 3

# Install Cloudflare Tunnel
echo "🌐 Setting up Cloudflare Tunnel..."
if ! command -v cloudflared &> /dev/null; then
  echo "📦 Installing cloudflared..."
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O $PREFIX/bin/cloudflared
  chmod +x $PREFIX/bin/cloudflared
fi

# Start tunnel
cloudflared tunnel --url http://localhost:3000 &
TUNNEL_PID=$!
sleep 5

# Get public URL
echo ""
echo "=========================================="
echo "✅ Leef Panel Installed Successfully!"
echo "=========================================="
echo ""
echo "👤 Admin Credentials:"
echo "   Username: admin"
echo "   Password: $ADMIN_PASS"
echo ""
echo "📍 Local URL: http://localhost:3000"
echo ""

# Try to get tunnel URL
TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' | head -1)

if [ -n "$TUNNEL_URL" ]; then
  echo "🌍 Public URL: $TUNNEL_URL"
  echo ""
  echo "📋 Save this URL to access from anywhere!"
  echo "$TUNNEL_URL" > ~/leef/panel-url.txt
else
  echo "🌍 Public URL: Check cloudflared output above"
  echo "   Look for: https://xxxxx.trycloudflare.com"
fi

echo ""
echo "=========================================="
echo "📱 Developed by LavaTeam-IR"
echo "🔗 https://github.com/LavaTeam-IR"
echo "=========================================="
echo ""
echo "💡 To keep running:"
echo "   - Don't close this terminal"
echo "   - Or use: tmux new-session -s leef 'cd ~/leef && node server.js'"
echo ""
echo "⚠️  If tunnel doesn't work, try:"
echo "   cloudflared tunnel --url http://localhost:3000"

# Save info
cat > ~/leef/README.txt << EOF
🍂 Leef Panel
=============
Username: admin
Password: $ADMIN_PASS
Local URL: http://localhost:3000
Public URL: $TUNNEL_URL
Installed: $(date)

Developed by LavaTeam-IR
EOF

echo ""
echo "📄 Info saved to: ~/leef/README.txt"
