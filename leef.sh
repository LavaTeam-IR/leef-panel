#!/bin/bash

# 🍂 Leef Panel - No NPM Installer
# Developed by LavaTeam-IR

clear
echo "🍂 Leef Panel Installer (No NPM)"
echo "=================================="
echo ""

# Check Termux
if [ ! -d "$PREFIX" ]; then
    echo "❌ This script is for Termux only!"
    exit 1
fi

# Update packages
echo "📦 Updating packages..."
pkg update -y && pkg upgrade -y

# Install Node.js only
echo "📦 Installing Node.js..."
pkg install -y nodejs-lts python wget curl

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js installation failed!"
    exit 1
fi

# Get admin password
echo ""
echo "🔐 Enter admin password:"
read -s ADMIN_PASS
echo ""

# Create directory
mkdir -p ~/leef
cd ~/leef

# Create full panel with embedded dependencies
cat > panel.js << 'EOF'
// 🍂 Leef Panel - Standalone (No NPM)
// Built-in dependencies using pure Node.js
// Developed by LavaTeam-IR

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sqlite3 = require('sqlite3');

// Simple bcrypt replacement (pure JS)
const bcrypt = {
  hashSync: (password, saltRounds) => {
    const salt = crypto.randomBytes(16).toString('base64');
    const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('base64');
    return `$2b$${salt}$${hash}`;
  },
  compareSync: (password, hash) => {
    try {
      const parts = hash.split('$');
      if (parts.length < 4) return false;
      const salt = parts[2];
      const originalHash = parts[3];
      const newHash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('base64');
      return newHash === originalHash;
    } catch(e) { return false; }
  }
};

// Simple JWT replacement
const jwt = {
  sign: (payload, secret, options) => {
    const header = { alg: 'HS256', typ: 'JWT' };
    const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64');
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64');
    const signature = crypto.createHmac('sha256', secret)
      .update(`${encodedHeader}.${encodedPayload}`)
      .digest('base64');
    return `${encodedHeader}.${encodedPayload}.${signature}`;
  },
  verify: (token, secret) => {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) throw new Error('Invalid token');
      const [header, payload, signature] = parts;
      const expectedSignature = crypto.createHmac('sha256', secret)
        .update(`${header}.${payload}`)
        .digest('base64');
      if (signature !== expectedSignature) throw new Error('Invalid signature');
      return JSON.parse(Buffer.from(payload, 'base64').toString());
    } catch(e) {
      throw new Error('Invalid token');
    }
  }
};

// Database
const db = new sqlite3.Database('./leef.db');

// Create tables
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    email TEXT,
    role TEXT DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT,
    details TEXT,
    ip TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
});

// HTML
const html = `<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>🍂 Leef Panel</title>
<script src="https://cdn.tailwindcss.com"></script>
<style>
*{font-family:system-ui;margin:0;padding:0}
body{background:#0d1117;color:#c9d1d9}
.card{background:#161b22;border-radius:12px;padding:20px;border:1px solid #30363d}
.btn{background:#238636;padding:10px 20px;border-radius:8px;border:none;color:#fff;cursor:pointer;font-weight:600}
.btn:hover{background:#2ea043}
.btn-danger{background:#da3633}
.btn-danger:hover{background:#f85149}
input{background:#0d1117;border:1px solid #30363d;padding:10px;border-radius:8px;color:#fff;width:100%;box-sizing:border-box;margin:5px 0}
.sidebar{background:#161b22;padding:20px;height:100vh;position:fixed;width:200px;border-right:1px solid #30363d}
.main{margin-left:220px;padding:20px}
.nav-item{padding:10px 12px;cursor:pointer;border-radius:8px;margin:4px 0}
.nav-item:hover{background:#30363d}
.nav-item.active{background:#238636}
.hidden{display:none!important}
.flex-center{display:flex;align-items:center;justify-content:center;min-height:100vh}
.w-96{max-width:400px;width:100%}
.text-gray{color:#8b949e}
.text-red{color:#f85149}
.text-green{color:#238636}
.border-b{border-bottom:1px solid #30363d}
.p-2{padding:8px}
.py-1{padding-top:4px;padding-bottom:4px}
.mt-2{margin-top:8px}
.mt-4{margin-top:16px}
.mb-2{margin-bottom:8px}
.mb-4{margin-bottom:16px}
.mb-6{margin-bottom:24px}
.gap-2{gap:8px}
.grid-3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.flex{display:flex}
.justify-between{justify-content:space-between}
.items-center{align-items:center}
.text-sm{font-size:14px}
.text-xs{font-size:12px}
.text-xl{font-size:24px}
.text-2xl{font-size:28px}
.text-3xl{font-size:32px}
.font-bold{font-weight:700}
.w-full{width:100%}
@media(max-width:768px){.grid-3{grid-template-columns:1fr}.sidebar{width:60px;padding:10px}.sidebar span{display:none}.main{margin-left:70px}}
</style>
</head>
<body>

<!-- Login -->
<div id="loginPage" class="flex-center">
  <div class="card w-96">
    <h1 class="text-2xl font-bold mb-2">🍂 Leef Panel</h1>
    <p class="text-gray mb-4">Sign in to dashboard</p>
    <input id="username" placeholder="Username" value="admin">
    <input id="password" type="password" placeholder="Password">
    <button onclick="login()" class="btn w-full mt-2">Sign In</button>
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
    <div class="nav-item text-red" style="margin-top:20px" onclick="logout()">🚪 <span>Logout</span></div>
    <div style="position:absolute;bottom:20px;font-size:11px;color:#8b949e">LavaTeam-IR</div>
  </div>

  <div class="main">
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

    <div id="page-users" class="hidden">
      <div class="flex justify-between items-center mb-4">
        <div><h2 class="text-2xl font-bold">Users</h2><p class="text-gray">Manage users</p></div>
        <button onclick="createUser()" class="btn">+ New User</button>
      </div>
      <div class="card" id="userList"></div>
    </div>

    <div id="page-logs" class="hidden">
      <div class="mb-4"><h2 class="text-2xl font-bold">Logs</h2><p class="text-gray">System logs</p></div>
      <div class="card" id="logList"></div>
    </div>
  </div>
</div>

<script>
let token = localStorage.getItem('token');
if(token){
  document.getElementById('loginPage').classList.add('hidden');
  document.getElementById('dashboardPage').classList.remove('hidden');
  loadData();
}

async function login(){
  const username = document.getElementById('username').value;
  const password = document.getElementById('password').value;
  try{
    const res = await fetch('/api/login', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({username,password})
    });
    const data = await res.json();
    if(!res.ok) throw new Error();
    localStorage.setItem('token', data.token);
    location.reload();
  }catch(e){
    document.getElementById('errorMsg').classList.remove('hidden');
  }
}

function logout(){
  localStorage.removeItem('token');
  location.reload();
}

function showPage(page){
  ['dashboard','users','logs'].forEach(p => document.getElementById('page-'+p).classList.add('hidden'));
  document.getElementById('page-'+page).classList.remove('hidden');
  document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
  event.target.classList.add('active');
  if(page==='users') loadUsers();
  if(page==='logs') loadLogs();
}

async function loadData(){
  try{
    const res = await fetch('/api/stats', {headers:{'Authorization':'Bearer '+token}});
    const data = await res.json();
    document.getElementById('statUsers').textContent = data.users||0;
    document.getElementById('statLogs').textContent = data.logs||0;
    document.getElementById('statOnline').textContent = data.active||0;
  }catch(e){}
  loadActivity();
}

async function loadActivity(){
  try{
    const res = await fetch('/api/logs?limit=5', {headers:{'Authorization':'Bearer '+token}});
    const logs = await res.json();
    document.getElementById('recentActivity').innerHTML = logs.map(l =>
      '<div class="flex justify-between items-center py-1 border-b border-gray-800">'+
        '<span>'+ (l.username||'System') +'</span>'+
        '<span class="text-gray text-sm">'+ l.action +'</span>'+
        '<span class="text-gray text-xs">'+ new Date(l.created_at).toLocaleString() +'</span>'+
      '</div>'
    ).join('') || '<div class="text-gray text-center py-4">No activity</div>';
  }catch(e){}
}

async function loadUsers(){
  try{
    const res = await fetch('/api/users', {headers:{'Authorization':'Bearer '+token}});
    const users = await res.json();
    document.getElementById('userList').innerHTML = users.map(u =>
      '<div class="flex justify-between items-center p-2 border-b border-gray-800">'+
        '<div><span class="font-bold">'+u.username+'</span><span class="text-gray text-sm ml-2">'+(u.email||'')+'</span></div>'+
        '<div><span class="text-xs px-2 py-1 bg-green-900 text-green rounded">'+u.role+'</span>'+
        (u.username!=='admin' ? '<button onclick="deleteUser('+u.id+')" class="btn-danger text-xs ml-2 px-2 py-1 rounded">Delete</button>' : '')+
      '</div></div>'
    ).join('');
  }catch(e){}
}

async function loadLogs(){
  try{
    const res = await fetch('/api/logs', {headers:{'Authorization':'Bearer '+token}});
    const logs = await res.json();
    document.getElementById('logList').innerHTML = logs.map(l =>
      '<div class="flex justify-between items-center py-1 border-b border-gray-800">'+
        '<span class="font-bold">'+(l.username||'System')+'</span>'+
        '<span>'+l.action+'</span>'+
        '<span class="text-gray text-xs">'+new Date(l.created_at).toLocaleString()+'</span>'+
      '</div>'
    ).join('') || '<div class="text-gray text-center py-4">No logs</div>';
  }catch(e){}
}

async function createUser(){
  const username = prompt('Enter username:');
  if(!username) return;
  const password = prompt('Enter password:');
  if(!password) return;
  const email = prompt('Enter email (optional):')||'';
  try{
    await fetch('/api/users', {
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},
      body:JSON.stringify({username,password,email,role:'user'})
    });
    loadUsers(); loadData();
    alert('User created!');
  }catch(e){ alert('Error creating user'); }
}

async function deleteUser(id){
  if(!confirm('Delete this user?')) return;
  try{
    await fetch('/api/users/'+id, {method:'DELETE', headers:{'Authorization':'Bearer '+token}});
    loadUsers(); loadData();
  }catch(e){ alert('Error deleting user'); }
}

setInterval(() => { if(token) loadData(); }, 30000);
</script>
</body>
</html>`;

// Simple router
const routes = {
  GET: {},
  POST: {}
};

function route(method, path, handler) {
  routes[method][path] = handler;
}

// Auth middleware
function auth(req, res) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'No token' }));
    return false;
  }
  try {
    const token = authHeader.split(' ')[1];
    jwt.verify(token, 'secret');
    return true;
  } catch(e) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Invalid token' }));
    return false;
  }
}

// Routes
route('POST', '/api/login', (req, res, body) => {
  const { username, password } = JSON.parse(body);
  db.get('SELECT * FROM users WHERE username = ?', [username], (err, user) => {
    if (err || !user) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: 'Invalid' }));
    }
    if (!bcrypt.compareSync(password, user.password)) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: 'Invalid' }));
    }
    const token = jwt.sign({ id: user.id, username: user.username }, 'secret', { expiresIn: '24h' });
    db.run('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?', [user.id]);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ token, user: { id: user.id, username: user.username, role: user.role } }));
  });
});

route('GET', '/api/stats', (req, res) => {
  if (!auth(req, res)) return;
  db.get('SELECT COUNT(*) as users FROM users', (e, u) => {
    db.get('SELECT COUNT(*) as logs FROM logs', (e, l) => {
      db.get("SELECT COUNT(*) as active FROM users WHERE last_login > datetime('now', '-1 day')", (e, a) => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ users: u?.users||0, logs: l?.logs||0, active: a?.active||0 }));
      });
    });
  });
});

route('GET', '/api/users', (req, res) => {
  if (!auth(req, res)) return;
  db.all('SELECT id, username, email, role FROM users', (err, users) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(users));
  });
});

route('POST', '/api/users', (req, res, body) => {
  if (!auth(req, res)) return;
  const { username, password, email, role } = JSON.parse(body);
  const hash = bcrypt.hashSync(password, 10);
  db.run('INSERT INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
    [username, hash, email||'', role||'user'],
    function(err) {
      if (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ error: 'Username exists' }));
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: this.lastID }));
    }
  );
});

route('DELETE', '/api/users/:id', (req, res) => {
  if (!auth(req, res)) return;
  const id = req.url.split('/')[3];
  if (parseInt(id) === 1) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'Cannot delete admin' }));
  }
  db.run('DELETE FROM users WHERE id = ?', [id], () => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
  });
});

route('GET', '/api/logs', (req, res) => {
  if (!auth(req, res)) return;
  const limit = parseInt(req.url.split('?limit=')[1]) || 50;
  db.all(
    `SELECT logs.*, users.username FROM logs LEFT JOIN users ON logs.user_id = users.id ORDER BY logs.created_at DESC LIMIT ?`,
    [limit],
    (err, logs) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(logs));
    }
  );
});

// Server
const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  const method = req.method;

  // Serve HTML for root or API routes
  if (url === '/' || url.startsWith('/api/')) {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      const routeKey = url.startsWith('/api/users/') && method === 'DELETE' ? '/api/users/:id' : url;
      
      if (routes[method] && routes[method][url]) {
        routes[method][url](req, res, body);
      } else if (routes[method] && routes[method][routeKey]) {
        routes[method][routeKey](req, res, body);
      } else {
        // Serve HTML for all other routes
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(html);
      }
    });
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
  }
});

// Create admin user if not exists
const adminPass = process.env.ADMIN_PASS || 'admin123';
const adminHash = bcrypt.hashSync(adminPass, 10);
db.run('INSERT OR IGNORE INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
  ['admin', adminHash, 'admin@leef.local', 'admin']);

const PORT = 3000;
server.listen(PORT, () => {
  console.log('🍂 Leef Panel running on http://localhost:' + PORT);
  console.log('👤 Admin: admin / ' + adminPass);
});
EOF

# Create admin user with password
export ADMIN_PASS="$ADMIN_PASS"
node -e "
const sqlite3 = require('sqlite3');
const crypto = require('crypto');
const db = new sqlite3.Database('./leef.db');

// Simple bcrypt
const hash = (password) => {
  const salt = crypto.randomBytes(16).toString('base64');
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('base64');
  return '\$2b\$' + salt + '\$' + hash;
};

const pass = process.env.ADMIN_PASS || 'admin123';
const hashed = hash(pass);

db.run('INSERT OR IGNORE INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
  ['admin', hashed, 'admin@leef.local', 'admin'],
  function(err) {
    if (err) console.error('Error:', err);
    else console.log('✅ Admin user created');
    db.close();
  }
);
"

# Start panel
echo "🚀 Starting Leef Panel..."
node panel.js &
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

# Get URL
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

# Get tunnel URL
TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' | head -1)

if [ -n "$TUNNEL_URL" ]; then
  echo "🌍 Public URL: $TUNNEL_URL"
  echo "$TUNNEL_URL" > ~/leef/panel-url.txt
else
  echo "🌍 Public URL: Check cloudflared output above"
fi

echo ""
echo "=========================================="
echo "📱 Developed by LavaTeam-IR"
echo "🔗 https://github.com/LavaTeam-IR"
echo "=========================================="

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
echo "📄 Public URL saved to: ~/leef/panel-url.txt"
