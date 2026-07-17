#!/bin/bash

# 🍂 Leef Panel - Termux Auto Installer
# Developed by LavaTeam-IR

echo "🍂 Leef Panel Installer for Termux"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Update and install dependencies
echo -e "${BLUE}📦 Updating packages...${NC}"
pkg update -y && pkg upgrade -y

echo -e "${BLUE}📦 Installing dependencies...${NC}"
pkg install -y nodejs-lts python git wget curl openssl-tool

# Install Cloudflare Tunnel
echo -e "${BLUE}🌐 Installing Cloudflare Tunnel...${NC}"
if ! command -v cloudflared &> /dev/null; then
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O $PREFIX/bin/cloudflared
    chmod +x $PREFIX/bin/cloudflared
    echo -e "${GREEN}✅ Cloudflare Tunnel installed${NC}"
fi

# Create project directory
echo -e "${BLUE}📁 Creating project...${NC}"
mkdir -p ~/leef-panel
cd ~/leef-panel

# Create package.json
cat > package.json << 'EOF'
{
  "name": "leef-panel",
  "version": "1.0.0",
  "description": "🍂 Leef Panel",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
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
require('dotenv').config();

const app = express();
const PORT = 3000;
const JWT_SECRET = 'leef-panel-secret-2024';

app.use(cors());
app.use(express.json());

const db = new sqlite3.Database('./leef.db');

db.serialize(() => {
  db.run(\`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    email TEXT,
    role TEXT DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
  )\`);

  db.run(\`CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT,
    details TEXT,
    ip TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )\`);

  db.run(\`CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )\`);
});

const authenticate = (req, res, next) => {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  db.get('SELECT * FROM users WHERE username = ?', [username], async (err, user) => {
    if (err || !user) return res.status(401).json({ error: 'Invalid credentials' });
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) return res.status(401).json({ error: 'Invalid credentials' });
    const token = jwt.sign({ id: user.id, username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '24h' });
    db.run('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?', [user.id]);
    res.json({ token, user: { id: user.id, username: user.username, email: user.email, role: user.role } });
  });
});

app.get('/api/users', authenticate, (req, res) => {
  db.all('SELECT id, username, email, role, created_at, last_login FROM users', (err, users) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(users);
  });
});

app.post('/api/users', authenticate, (req, res) => {
  const { username, password, email, role } = req.body;
  const hashedPassword = bcrypt.hashSync(password, 10);
  db.run('INSERT INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
    [username, hashedPassword, email || '', role || 'user'],
    function(err) {
      if (err) return res.status(400).json({ error: 'Username exists' });
      db.get('SELECT id, username, email, role FROM users WHERE id = ?', [this.lastID], (err, user) => {
        res.json(user);
      });
    }
  );
});

app.delete('/api/users/:id', authenticate, (req, res) => {
  const userId = req.params.id;
  if (parseInt(userId) === req.user.id) {
    return res.status(400).json({ error: 'Cannot delete yourself' });
  }
  db.run('DELETE FROM users WHERE id = ?', [userId], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'User deleted' });
  });
});

app.get('/api/logs', authenticate, (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  db.all(
    \`SELECT logs.*, users.username FROM logs LEFT JOIN users ON logs.user_id = users.id ORDER BY logs.created_at DESC LIMIT ?\`,
    [limit],
    (err, logs) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(logs);
    }
  );
});

app.get('/api/stats', authenticate, (req, res) => {
  db.get('SELECT COUNT(*) as users FROM users', (err, userCount) => {
    db.get('SELECT COUNT(*) as logs FROM logs', (err, logCount) => {
      db.get('SELECT COUNT(*) as active FROM users WHERE last_login > datetime("now", "-1 day")', (err, activeCount) => {
        res.json({
          users: userCount?.users || 0,
          logs: logCount?.logs || 0,
          active: activeCount?.active || 0
        });
      });
    });
  });
});

app.get('/api/settings', authenticate, (req, res) => {
  db.all('SELECT * FROM settings', (err, settings) => {
    if (err) return res.status(500).json({ error: err.message });
    const settingsObj = {};
    settings.forEach(s => settingsObj[s.key] = s.value);
    res.json(settingsObj);
  });
});

app.post('/api/settings', authenticate, (req, res) => {
  const { key, value } = req.body;
  db.run('INSERT OR REPLACE INTO settings (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)',
    [key, value],
    (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Setting updated' });
    }
  );
});

app.get('*', (req, res) => {
  res.sendFile(__dirname + '/public/index.html');
});

app.listen(PORT, () => {
  console.log(\`🍂 Leef Panel running on http://localhost:\${PORT}\`);
});
EOF

# Create index.html (mini version)
mkdir -p public
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>🍂 لیف پنل</title>
<script src="https://cdn.tailwindcss.com"></script>
<style>
*{font-family:system-ui,sans-serif}
.sidebar{background:#1a1e24}
.sidebar-item:hover{background:rgba(74,143,69,0.1)}
.sidebar-item.active{background:rgba(74,143,69,0.2);border-right:3px solid #4a8f45}
.card{background:#242a33;transition:all .3s}
.card:hover{transform:translateY(-2px);box-shadow:0 8px 30px rgba(0,0,0,.3)}
.bg-main{background:#0d1117}
.fade-in{animation:fadeIn .3s ease-in}
@keyframes fadeIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
.status-dot{width:8px;height:8px;border-radius:50%;display:inline-block}
.status-dot.online{background:#4a8f45}
.status-dot.offline{background:#dc3545}
</style>
</head>
<body class="bg-main text-white">
<div id="app">
<div id="loginPage" class="min-h-screen flex items-center justify-center p-4">
<div class="bg-[#242a33] p-8 rounded-2xl w-full max-w-md card">
<div class="text-center mb-8"><div class="text-4xl mb-2">🍂</div><h1 class="text-3xl font-bold">لیف پنل</h1><p class="text-gray-400 mt-1">ورود به داشبورد</p></div>
<form id="loginForm" onsubmit="handleLogin(event)">
<div class="mb-4"><label class="block text-gray-300 mb-2">نام کاربری</label><input type="text" id="username" class="w-full px-4 py-3 bg-[#1a1e24] border border-gray-700 rounded-lg text-white focus:border-green-500 focus:outline-none"></div>
<div class="mb-6"><label class="block text-gray-300 mb-2">رمز عبور</label><input type="password" id="password" class="w-full px-4 py-3 bg-[#1a1e24] border border-gray-700 rounded-lg text-white focus:border-green-500 focus:outline-none"></div>
<button type="submit" class="w-full bg-[#4a8f45] hover:bg-[#3a7236] py-3 rounded-lg font-semibold transition">ورود</button>
</form>
<div id="loginError" class="text-red-500 text-center mt-3 hidden"></div>
</div>
</div>
<div id="dashboardPage" class="hidden">
<div class="flex h-screen">
<div class="sidebar w-64 flex-shrink-0 h-screen sticky top-0 overflow-y-auto">
<div class="p-6">
<div class="flex items-center gap-2 mb-8"><span class="text-2xl">🍂</span><span class="text-xl font-bold">لیف پنل</span></div>
<nav>
<div class="sidebar-item active px-4 py-3 rounded-lg cursor-pointer" onclick="showPage('dashboard')">📊 داشبورد</div>
<div class="sidebar-item px-4 py-3 rounded-lg cursor-pointer mt-1" onclick="showPage('users')">👥 کاربران</div>
<div class="sidebar-item px-4 py-3 rounded-lg cursor-pointer mt-1" onclick="showPage('logs')">📝 گزارشات</div>
<div class="sidebar-item px-4 py-3 rounded-lg cursor-pointer mt-1" onclick="showPage('settings')">⚙️ تنظیمات</div>
<div class="sidebar-item px-4 py-3 rounded-lg cursor-pointer mt-8 text-red-400" onclick="handleLogout()">🚪 خروج</div>
</nav>
<div class="mt-8 pt-4 border-t border-gray-700 text-xs text-gray-500 text-center">LavaTeam-IR</div>
</div>
</div>
<div class="flex-1 overflow-y-auto p-6">
<div id="page-dashboard" class="fade-in">
<div class="mb-6"><h1 class="text-2xl font-bold">داشبورد</h1><p class="text-gray-400">خلاصه وضعیت</p></div>
<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
<div class="card p-6 rounded-xl"><div class="text-gray-400 text-sm">کاربران</div><div class="text-3xl font-bold mt-2" id="statUsers">0</div></div>
<div class="card p-6 rounded-xl"><div class="text-gray-400 text-sm">گزارشات</div><div class="text-3xl font-bold mt-2" id="statLogs">0</div></div>
<div class="card p-6 rounded-xl"><div class="text-gray-400 text-sm">آنلاین</div><div class="text-3xl font-bold mt-2" id="statActive">0</div></div>
</div>
<div class="card p-6 rounded-xl"><h3 class="font-semibold mb-4">فعالیت‌های اخیر</h3><div id="recentActivities" class="space-y-2"></div></div>
</div>
<div id="page-users" class="hidden fade-in">
<div class="mb-6 flex justify-between items-center"><div><h1 class="text-2xl font-bold">کاربران</h1><p class="text-gray-400">مدیریت کاربران</p></div><button onclick="showUserForm()" class="bg-[#4a8f45] hover:bg-[#3a7236] px-4 py-2 rounded-lg transition">+ جدید</button></div>
<div class="card rounded-xl overflow-hidden"><table class="w-full"><thead class="bg-[#1a1e24]"><tr><th class="text-right p-4 text-gray-400 text-sm">نام کاربری</th><th class="text-right p-4 text-gray-400 text-sm">ایمیل</th><th class="text-right p-4 text-gray-400 text-sm">نقش</th><th class="text-right p-4 text-gray-400 text-sm">وضعیت</th><th class="text-right p-4 text-gray-400 text-sm">عملیات</th></tr></thead><tbody id="usersTableBody"></tbody></table></div>
</div>
<div id="page-logs" class="hidden fade-in">
<div class="mb-6"><h1 class="text-2xl font-bold">گزارشات</h1><p class="text-gray-400">لاگ‌های سیستم</p></div>
<div class="card rounded-xl overflow-hidden"><table class="w-full"><thead class="bg-[#1a1e24]"><tr><th class="text-right p-4 text-gray-400 text-sm">کاربر</th><th class="text-right p-4 text-gray-400 text-sm">عملیات</th><th class="text-right p-4 text-gray-400 text-sm">جزئیات</th><th class="text-right p-4 text-gray-400 text-sm">زمان</th></tr></thead><tbody id="logsTableBody"></tbody></table></div>
</div>
<div id="page-settings" class="hidden fade-in">
<div class="mb-6"><h1 class="text-2xl font-bold">تنظیمات</h1><p class="text-gray-400">مدیریت تنظیمات</p></div>
<div class="card p-6 rounded-xl max-w-2xl"><div class="space-y-4">
<div><label class="block text-gray-300 mb-2">نام سایت</label><input type="text" id="siteName" class="w-full px-4 py-2 bg-[#1a1e24] border border-gray-700 rounded-lg text-white focus:border-green-500 focus:outline-none"></div>
<div><label class="block text-gray-300 mb-2">تم</label><select id="siteTheme" class="w-full px-4 py-2 bg-[#1a1e24] border border-gray-700 rounded-lg text-white focus:border-green-500 focus:outline-none"><option value="dark">تاریک</option><option value="light">روشن</option></select></div>
<button onclick="saveSettings()" class="bg-[#4a8f45] hover:bg-[#3a7236] px-6 py-2 rounded-lg transition">ذخیره</button>
</div></div>
</div>
</div>
</div>
</div>
</div>
<script>
let token=localStorage.getItem('token');
if(token){document.getElementById('loginPage').classList.add('hidden');document.getElementById('dashboardPage').classList.remove('hidden');loadData();}
async function handleLogin(e){e.preventDefault();const username=document.getElementById('username').value;const password=document.getElementById('password').value;const errorEl=document.getElementById('loginError');try{const res=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username,password})});const data=await res.json();if(!res.ok)throw new Error(data.error);localStorage.setItem('token',data.token);token=data.token;document.getElementById('loginPage').classList.add('hidden');document.getElementById('dashboardPage').classList.remove('hidden');loadData();}catch(err){errorEl.textContent='نام کاربری یا رمز عبور اشتباه است';errorEl.classList.remove('hidden');}}
function handleLogout(){localStorage.removeItem('token');token=null;document.getElementById('loginPage').classList.remove('hidden');document.getElementById('dashboardPage').classList.add('hidden');}
function showPage(page){document.querySelectorAll('[id^="page-"]').forEach(el=>el.classList.add('hidden'));document.getElementById('page-'+page).classList.remove('hidden');document.querySelectorAll('.sidebar-item').forEach(el=>el.classList.remove('active'));event.target.classList.add('active');}
async function loadData(){await loadStats();await loadUsers();await loadLogs();await loadSettings();await loadActivities();}
async function loadStats(){try{const res=await fetch('/api/stats',{headers:{'Authorization':'Bearer '+token}});const data=await res.json();document.getElementById('statUsers').textContent=data.users||0;document.getElementById('statLogs').textContent=data.logs||0;document.getElementById('statActive').textContent=data.active||0;}catch(err){}}
async function loadUsers(){try{const res=await fetch('/api/users',{headers:{'Authorization':'Bearer '+token}});const users=await res.json();document.getElementById('usersTableBody').innerHTML=users.map(user=>'<tr class="border-b border-gray-800"><td class="p-4">'+user.username+'</td><td class="p-4 text-gray-400">'+(user.email||'-')+'</td><td class="p-4"><span class="px-2 py-1 bg-[#4a8f45] bg-opacity-20 text-green-500 rounded text-xs">'+user.role+'</span></td><td class="p-4"><span class="status-dot '+(user.last_login?'online':'offline')+'"></span></td><td class="p-4">'+(user.username!=='admin'?'<button onclick="deleteUser('+user.id+')" class="text-red-400 hover:text-red-300">🗑️</button>':'<span class="text-gray-500 text-xs">ادمین</span>')+'</td></tr>').join('');}catch(err){}}
async function deleteUser(id){if(!confirm('حذف کاربر؟'))return;try{await fetch('/api/users/'+id,{method:'DELETE',headers:{'Authorization':'Bearer '+token}});loadUsers();loadStats();}catch(err){}}
function showUserForm(){const username=prompt('نام کاربری:');if(!username)return;const password=prompt('رمز عبور:');if(!password)return;const email=prompt('ایمیل:')||'';createUser(username,password,email);}
async function createUser(username,password,email){try{const res=await fetch('/api/users',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify({username,password,email,role:'user'})});if(res.ok){loadUsers();loadStats();alert('کاربر ایجاد شد');}}catch(err){}}
async function loadLogs(){try{const res=await fetch('/api/logs',{headers:{'Authorization':'Bearer '+token}});const logs=await res.json();document.getElementById('logsTableBody').innerHTML=logs.map(log=>'<tr class="border-b border-gray-800"><td class="p-4">'+(log.username||'سیستم')+'</td><td class="p-4">'+log.action+'</td><td class="p-4 text-gray-400">'+(log.details||'-')+'</td><td class="p-4 text-gray-400 text-sm">'+new Date(log.created_at).toLocaleString('fa-IR')+'</td></tr>').join('');}catch(err){}}
async function loadActivities(){try{const res=await fetch('/api/logs?limit=5',{headers:{'Authorization':'Bearer '+token}});const logs=await res.json();document.getElementById('recentActivities').innerHTML=logs.map(log=>'<div class="flex justify-between items-center py-2 border-b border-gray-800"><span>'+(log.username||'سیستم')+' - '+log.action+'</span><span class="text-gray-500 text-xs">'+new Date(log.created_at).toLocaleString('fa-IR')+'</span></div>').join('')||'<div class="text-gray-500 text-center py-4">هیچ فعالیتی ثبت نشده</div>';}catch(err){}}
async function loadSettings(){try{const res=await fetch('/api/settings',{headers:{'Authorization':'Bearer '+token}});const settings=await res.json();document.getElementById('siteName').value=settings.site_name||'لیف پنل';document.getElementById('siteTheme').value=settings.site_theme||'dark';}catch(err){}}
async function saveSettings(){const siteName=document.getElementById('siteName').value;const siteTheme=document.getElementById('siteTheme').value;try{await fetch('/api/settings',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify({key:'site_name',value:siteName})});await fetch('/api/settings',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},body:JSON.stringify({key:'site_theme',value:siteTheme})});alert('تنظیمات ذخیره شد');}catch(err){}}
setInterval(()=>{if(token){loadStats();loadActivities();}},30000);
</script>
</body>
</html>
EOF

# Install npm packages
echo -e "${BLUE}📦 Installing npm packages...${NC}"
npm install

# Ask for admin password
echo ""
echo -e "${YELLOW}🔐 Enter admin panel password:${NC}"
read -s ADMIN_PASSWORD
echo ""

# Create admin user
echo -e "${BLUE}👤 Creating admin user...${NC}"
node -e "
const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcryptjs');
const db = new sqlite3.Database('./leef.db');
const password = '$ADMIN_PASSWORD';
const hashedPassword = bcrypt.hashSync(password, 10);
db.run('INSERT OR IGNORE INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
  ['admin', hashedPassword, 'admin@leef.ir', 'admin'],
  function(err) {
    if (err) console.error('Error:', err);
    else console.log('✅ Admin user created');
    db.close();
  }
);
"

# Start server
echo -e "${BLUE}🚀 Starting Leef Panel...${NC}"
node server.js &
SERVER_PID=$!

sleep 3

# Start Cloudflare Tunnel
echo -e "${BLUE}🌐 Starting Cloudflare Tunnel...${NC}"
cloudflared tunnel --url http://localhost:3000 &
TUNNEL_PID=$!

sleep 5

# Get tunnel URL
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Leef Panel installed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}🌐 Access your panel:${NC}"
echo -e "${BLUE}Local: http://localhost:3000${NC}"
echo ""

# Try to get tunnel URL
TUNNEL_URL=$(curl -s http://localhost:3000 2>/dev/null | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' | head -1)

if [ -z "$TUNNEL_URL" ]; then
    echo -e "${YELLOW}⚠️  Could not auto-detect tunnel URL${NC}"
    echo -e "${YELLOW}Check cloudflared logs above for your URL${NC}"
else
    echo -e "${GREEN}🌍 Public URL: ${TUNNEL_URL}${NC}"
    echo "$TUNNEL_URL" > ~/leef-panel/panel-url.txt
    echo -e "${GREEN}✅ URL saved to: ~/leef-panel/panel-url.txt${NC}"
fi

echo ""
echo -e "${GREEN}👤 Admin Credentials:${NC}"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${GREEN}$ADMIN_PASSWORD${NC}"
echo ""
echo -e "${BLUE}📱 Developed by LavaTeam-IR${NC}"
echo ""

wait