#!/bin/bash

# ============================================
# 🍂 Leef Panel - Cloudflare Worker Installer
# نصب‌کننده خودکار پنل روی Cloudflare Workers
# ============================================

# رنگ‌ها برای ترمینال
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# توابع کمکی
# ============================================

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     🍂  LEEF PANEL - CLOUDFLARE WORKER INSTALLER  🍂       ║"
    echo "║                                                              ║"
    echo "║          نسخه 2.0 - نصب خودکار روی Cloudflare               ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================
# بررسی پیش‌نیازها
# ============================================

check_dependencies() {
    print_step "بررسی پیش‌نیازها..."
    
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v node &> /dev/null; then
        missing+=("node")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "ابزارهای زیر نصب نیستند: ${missing[*]}"
        print_info "در حال نصب با pkg..."
        
        for tool in "${missing[@]}"; do
            if [ "$tool" == "jq" ]; then
                pkg install jq -y
            elif [ "$tool" == "curl" ]; then
                pkg install curl -y
            elif [ "$tool" == "node" ]; then
                pkg install nodejs -y
            fi
        done
        
        # بررسی مجدد
        for tool in "${missing[@]}"; do
            if ! command -v "$tool" &> /dev/null; then
                print_error "نصب $tool ناموفق بود. لطفاً دستی نصب کنید."
                exit 1
            fi
        done
    fi
    
    print_success "همه پیش‌نیازها نصب هستند"
}

# ============================================
# گرفتن توکن و اطلاعات کاربر
# ============================================

get_credentials() {
    print_step "ورود اطلاعات Cloudflare..."
    echo ""
    
    read -p "👉 Email Cloudflare: " CF_EMAIL
    read -sp "👉 API Token Cloudflare: " CF_TOKEN
    echo ""
    read -p "👉 Account ID Cloudflare: " CF_ACCOUNT_ID
    echo ""
    
    if [ -z "$CF_EMAIL" ] || [ -z "$CF_TOKEN" ] || [ -z "$CF_ACCOUNT_ID" ]; then
        print_error "همه فیلدها الزامی هستند!"
        exit 1
    fi
    
    # تست توکن
    print_step "در حال تست توکن..."
    TEST_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$TEST_RESPONSE" | grep -q '"success":false'; then
        print_error "توکن یا Account ID معتبر نیست!"
        echo "$TEST_RESPONSE" | jq '.errors'
        exit 1
    fi
    
    print_success "احراز هویت موفقیت‌آمیز بود!"
}

# ============================================
# تولید نام رندوم
# ============================================

generate_random_name() {
    local prefix="leefpanel"
    local random_num=$(shuf -i 100000-999999 -n 1)
    echo "${prefix}${random_num}"
}

# ============================================
# کد Worker
# ============================================

generate_worker_code() {
    local admin_pass=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
    
    cat <<'EOF'
// ============================================
// 🍂 leef panel - Cloudflare Worker
// نسخه: 2.0
// ============================================

const CONFIG = {
  ADMIN_PASSWORD: 'ADMIN_PASS_PLACEHOLDER',
  
  PUBLIC_SOURCES: [
    'https://raw.githubusercontent.com/MahsaN/...',
    'https://raw.githubusercontent.com/hamedp-71/Trojan/...',
  ],
  
  IRAN_SOURCES: [
    'https://raw.githubusercontent.com/MatinGhanbari/v2ray-config/...',
  ],
  
  ALLOWED_PORTS: ['80', '443', '8080', '8443', '2052', '2053', '2095', '2096'],
  CONFIG_LIMITS: [12, 24, 36, 45, 60, 100],
  CACHE_TTL: 21600,
  CONCURRENCY_LIMIT: 5
};

// ==================== کلاس کش ====================
class LeefCache {
  constructor() {
    this.cache = new Map();
    this.hits = 0;
    this.misses = 0;
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item || item.expiry < Date.now()) {
      this.misses++;
      this.cache.delete(key);
      return null;
    }
    this.hits++;
    return item.data;
  }

  set(key, data, ttl = CONFIG.CACHE_TTL) {
    this.cache.set(key, {
      data: data,
      expiry: Date.now() + (ttl * 1000)
    });
  }

  clear() {
    this.cache.clear();
    this.hits = 0;
    this.misses = 0;
  }
}

const cache = new LeefCache();

// ==================== توابع کمکی ====================
function detectProtocol(url) {
  if (url.startsWith('vless://')) return 'vless';
  if (url.startsWith('trojan://')) return 'trojan';
  if (url.startsWith('ss://')) return 'shadowsocks';
  return 'unknown';
}

function isValidConfig(url) {
  try {
    const portMatch = url.match(/:(\d+)/);
    if (!portMatch) return false;
    const port = portMatch[1];
    if (!CONFIG.ALLOWED_PORTS.includes(port)) return false;

    const domainMatch = url.match(/@([^:]+):/);
    if (!domainMatch) return false;
    const domain = domainMatch[1];
    return /^[a-z0-9][a-z0-9-]{0,61}[a-z0-9](\.[a-z0-9][a-z0-9-]{0,61}[a-z0-9])*$/i.test(domain);
  } catch {
    return false;
  }
}

// ==================== دریافت کانفیگ ====================
async function fetchConfigs(urls, limit = 'all') {
  const results = new Set();
  const concurrency = CONFIG.CONCURRENCY_LIMIT;

  for (let i = 0; i < urls.length; i += concurrency) {
    const batch = urls.slice(i, i + concurrency);
    const promises = batch.map(url => fetchSingleConfig(url));
    const responses = await Promise.all(promises);
    
    for (const response of responses) {
      if (response && response.length) {
        for (const config of response) {
          results.add(config);
        }
      }
    }
  }

  let configs = Array.from(results);
  
  if (limit !== 'all') {
    const limitNum = parseInt(limit) || 12;
    configs = configs.slice(0, limitNum);
  }

  return configs;
}

async function fetchSingleConfig(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) return [];

    const text = await response.text();
    const lines = text.split('\n');
    const validConfigs = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      if (isValidConfig(trimmed)) {
        validConfigs.push(trimmed);
      }
    }

    return validConfigs;
  } catch (e) {
    return [];
  }
}

// ==================== صفحه Login ====================
function generateLoginPage() {
  return `
<!DOCTYPE html>
<html dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🍂 ورود به پنل</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background: linear-gradient(135deg, #1a1a2e, #16213e);
    }
    .login-container {
      background: rgba(255,255,255,0.05);
      backdrop-filter: blur(20px);
      padding: 40px;
      border-radius: 20px;
      width: 100%;
      max-width: 400px;
      border: 1px solid rgba(255,255,255,0.1);
      box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    }
    .login-title {
      text-align: center;
      color: #8A2BE2;
      font-size: 28px;
      margin-bottom: 30px;
      font-weight: 700;
    }
    .login-title span { color: #FF8C00; }
    .input-group { margin-bottom: 25px; position: relative; }
    .input-group input {
      width: 100%;
      padding: 15px;
      background: rgba(255,255,255,0.1);
      border: none;
      border-bottom: 2px solid rgba(255,255,255,0.2);
      color: #fff;
      font-size: 16px;
      transition: all 0.3s;
      border-radius: 8px;
    }
    .input-group input:focus {
      outline: none;
      border-color: #8A2BE2;
      background: rgba(255,255,255,0.15);
    }
    .input-group input::placeholder { color: rgba(255,255,255,0.5); }
    .btn-login {
      width: 100%;
      padding: 15px;
      background: linear-gradient(135deg, #8A2BE2, #DA70D6);
      color: white;
      border: none;
      border-radius: 10px;
      font-size: 18px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s;
    }
    .btn-login:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 25px rgba(138, 43, 226, 0.4);
    }
    .error-message {
      background: rgba(255, 0, 0, 0.1);
      border: 1px solid rgba(255, 0, 0, 0.3);
      color: #ff6b6b;
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 20px;
      display: none;
      text-align: center;
    }
    .footer {
      text-align: center;
      margin-top: 20px;
      color: rgba(255,255,255,0.4);
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="login-container">
    <div class="login-title">🍂 leef <span>panel</span></div>
    <div id="errorMessage" class="error-message">رمز عبور اشتباه است!</div>
    <form id="loginForm">
      <div class="input-group">
        <input type="password" id="password" placeholder="رمز عبور را وارد کنید" required>
      </div>
      <button type="submit" class="btn-login">ورود به پنل</button>
    </form>
  </div>
  <script>
    document.getElementById('loginForm').addEventListener('submit', async function(e) {
      e.preventDefault();
      const password = document.getElementById('password').value;
      const errorElement = document.getElementById('errorMessage');
      errorElement.style.display = 'none';
      
      if (password.length < 8) {
        errorElement.textContent = 'رمز عبور باید حداقل ۸ کاراکتر باشد';
        errorElement.style.display = 'block';
        return;
      }

      try {
        const response = await fetch('/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ password })
        });

        if (response.ok) {
          window.location.href = '/panel';
        } else {
          errorElement.textContent = 'رمز عبور وارد شده نامعتبر است';
          errorElement.style.display = 'block';
        }
      } catch (error) {
        errorElement.textContent = 'خطا در ارتباط با سرور';
        errorElement.style.display = 'block';
      }
    });
  </script>
</body>
</html>
  `;
}

// ==================== هندلر اصلی ====================
async function handleRequest(request) {
  const url = new URL(request.url);
  const path = url.pathname;

  // ورود
  if (path === '/login' && request.method === 'POST') {
    try {
      const body = await request.json();
      if (body.password === CONFIG.ADMIN_PASSWORD) {
        return new Response(JSON.stringify({ success: true }), {
          headers: {
            'Content-Type': 'application/json',
            'Set-Cookie': `auth=${btoa(body.password)}; Path=/; HttpOnly; Secure; SameSite=Strict`
          }
        });
      }
      return new Response(JSON.stringify({ success: false, error: 'رمز عبور اشتباه است' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    } catch {
      return new Response(JSON.stringify({ success: false, error: 'خطا در پردازش' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }

  // خروج
  if (path === '/logout' && request.method === 'POST') {
    return new Response(JSON.stringify({ success: true }), {
      headers: {
        'Content-Type': 'application/json',
        'Set-Cookie': 'auth=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; Secure; SameSite=Strict'
      }
    });
  }

  // پنل
  if (path === '/panel') {
    const cookie = request.headers.get('Cookie');
    if (cookie && cookie.includes('auth=')) {
      const auth = cookie.split(';').find(c => c.trim().startsWith('auth='));
      if (auth) {
        const value = auth.split('=')[1];
        if (atob(value) === CONFIG.ADMIN_PASSWORD) {
          return new Response(generatePanelPage(), {
            headers: { 'Content-Type': 'text/html; charset=utf-8' }
          });
        }
      }
    }
    return Response.redirect(url.origin + '/', 302);
  }

  // صفحه اصلی
  if (path === '/' || path === '') {
    const cookie = request.headers.get('Cookie');
    if (cookie && cookie.includes('auth=')) {
      const auth = cookie.split(';').find(c => c.trim().startsWith('auth='));
      if (auth) {
        const value = auth.split('=')[1];
        if (atob(value) === CONFIG.ADMIN_PASSWORD) {
          return Response.redirect(url.origin + '/panel', 302);
        }
      }
    }
    return new Response(generateLoginPage(), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' }
    });
  }

  // دریافت کانفیگ
  const cacheKey = path + url.search;
  const cached = cache.get(cacheKey);
  if (cached) {
    return new Response(cached, {
      headers: { 
        'Content-Type': 'text/plain; charset=utf-8',
        'X-Cache': 'HIT'
      }
    });
  }

  const params = url.searchParams;
  const ports = params.get('ports')?.split(',').filter(p => CONFIG.ALLOWED_PORTS.includes(p)) || [];
  const limit = params.get('limit') || 'all';
  const protocol = params.get('protocol') || 'all';

  let configs = [];

  if (path === '/public') {
    configs = await fetchConfigs(CONFIG.PUBLIC_SOURCES, limit);
  } else if (path === '/iran') {
    configs = await fetchConfigs(CONFIG.IRAN_SOURCES, limit);
  } else if (path === '/all') {
    const publicConfigs = await fetchConfigs(CONFIG.PUBLIC_SOURCES, limit);
    const iranConfigs = await fetchConfigs(CONFIG.IRAN_SOURCES, limit);
    configs = [...publicConfigs, ...iranConfigs];
  } else {
    return new Response('مسیر یافت نشد', { status: 404 });
  }

  // فیلتر پورت
  if (ports.length) {
    configs = configs.filter(c => {
      const port = c.match(/:(\d+)/)?.[1];
      return ports.includes(port);
    });
  }

  // فیلتر پروتکل
  if (protocol !== 'all') {
    configs = configs.filter(c => detectProtocol(c) === protocol);
  }

  const responseData = configs.join('\n');
  cache.set(cacheKey, responseData);

  return new Response(responseData, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'X-Cache': 'MISS',
      'X-Config-Count': configs.length
    }
  });
}

// ==================== صفحه Panel ====================
function generatePanelPage() {
  return `
<!DOCTYPE html>
<html dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🍂 leef panel</title>
  <style>
    :root {
      --primary: #8A2BE2;
      --secondary: #DA70D6;
      --success: #3CB371;
      --danger: #FF6347;
      --warning: #FFD700;
      --info: #1E90FF;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e, #16213e);
      min-height: 100vh;
      color: #fff;
      padding: 20px;
    }
    .panel-container { max-width: 1200px; margin: 0 auto; }
    .panel-header {
      background: rgba(255,255,255,0.05);
      backdrop-filter: blur(10px);
      padding: 20px 30px;
      border-radius: 15px;
      margin-bottom: 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .panel-title {
      font-size: 24px;
      font-weight: 700;
      background: linear-gradient(to right, var(--primary), var(--secondary));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .btn-logout {
      padding: 10px 20px;
      background: linear-gradient(135deg, var(--danger), #FF4500);
      color: white;
      border: none;
      border-radius: 10px;
      cursor: pointer;
    }
    .btn-logout:hover { transform: translateY(-2px); box-shadow: 0 8px 25px rgba(255,99,71,0.3); }
    .section-title { font-size: 20px; margin: 30px 0 20px; color: var(--primary); }
    .cards-container {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
      gap: 15px;
      margin: 20px 0;
    }
    .card {
      background: rgba(255,255,255,0.05);
      backdrop-filter: blur(5px);
      padding: 15px;
      border-radius: 12px;
      border: 1px solid rgba(255,255,255,0.1);
      cursor: pointer;
      transition: all 0.3s;
      text-align: center;
    }
    .card:hover { transform: translateY(-3px); box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
    .card.selected { border: 2px solid var(--primary); background: rgba(138,43,226,0.15); }
    .card-title { font-size: 14px; font-weight: 600; }
    .card-description { font-size: 11px; color: rgba(255,255,255,0.6); }
    .result-container {
      background: rgba(255,255,255,0.05);
      padding: 25px;
      border-radius: 15px;
      margin-top: 30px;
      display: none;
    }
    .result-box {
      background: rgba(0,0,0,0.3);
      padding: 15px;
      border-radius: 10px;
      word-break: break-all;
      font-family: monospace;
      margin-bottom: 15px;
    }
    .btn-copy {
      padding: 12px 30px;
      background: linear-gradient(135deg, var(--success), #2E8B57);
      color: white;
      border: none;
      border-radius: 10px;
      cursor: pointer;
    }
    .btn-refresh {
      padding: 10px 20px;
      background: linear-gradient(135deg, var(--info), #1E90FF);
      color: white;
      border: none;
      border-radius: 10px;
      cursor: pointer;
    }
    .btn-refresh:hover { transform: rotate(180deg); transition: all 0.5s; }
    .alert {
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      padding: 15px 30px;
      background: var(--success);
      color: white;
      border-radius: 10px;
      display: none;
      z-index: 1000;
    }
    .version-badge {
      position: fixed;
      bottom: 20px;
      right: 20px;
      padding: 8px 15px;
      background: rgba(255,255,255,0.1);
      border-radius: 20px;
      font-size: 12px;
      color: rgba(255,255,255,0.5);
    }
    .accordion {
      margin: 10px 0;
    }
    .accordion-header {
      background: rgba(255,255,255,0.05);
      padding: 15px 20px;
      border-radius: 10px;
      cursor: pointer;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .accordion-content {
      max-height: 0;
      overflow: hidden;
      transition: max-height 0.3s ease-out;
    }
    .accordion.active .accordion-content {
      max-height: 500px;
      padding-top: 15px;
    }
    @media (max-width: 768px) {
      .cards-container { grid-template-columns: repeat(2, 1fr); }
      .panel-header { flex-direction: column; gap: 10px; }
    }
  </style>
</head>
<body>
  <div class="panel-container">
    <header class="panel-header">
      <h1 class="panel-title">🍂 leef panel</h1>
      <div style="display:flex; gap:10px;">
        <button class="btn-refresh" id="refreshBtn">🔄</button>
        <button class="btn-logout" id="logoutBtn">🚪 خروج</button>
      </div>
    </header>

    <div id="alert" class="alert"></div>
    <div class="version-badge">ورژن 2.5.3</div>

    <div class="accordion" id="protocolAccordion">
      <div class="accordion-header" id="protocolAccordionHeader">
        <span>📡 انتخاب پروتکل</span>
        <span>▼</span>
      </div>
      <div class="accordion-content">
        <div class="cards-container" id="protocolContainer">
          <div class="card protocol-card selected" data-protocol="all"><div class="card-title">همه</div></div>
          <div class="card protocol-card" data-protocol="vless"><div class="card-title">VLESS</div></div>
          <div class="card protocol-card" data-protocol="trojan"><div class="card-title">Trojan</div></div>
          <div class="card protocol-card" data-protocol="shadowsocks"><div class="card-title">Shadowsocks</div></div>
        </div>
      </div>
    </div>

    <div class="accordion" id="portsAccordion">
      <div class="accordion-header" id="portsAccordionHeader">
        <span>🔌 انتخاب پورت‌ها</span>
        <span>▼</span>
      </div>
      <div class="accordion-content">
        <div class="cards-container" id="portsContainer">
          ${['80','443','8080','8443','2052','2053','2095','2096'].map(p => `
            <div class="card port-card" data-port="${p}"><div class="card-title">پورت ${p}</div></div>
          `).join('')}
        </div>
      </div>
    </div>

    <h2 class="section-title">🌍 انتخاب گروه</h2>
    <div class="cards-container" id="groupContainer">
      <div class="card group-card selected" data-group="public"><div class="card-title">عمومی 🌐</div></div>
      <div class="card group-card" data-group="iran"><div class="card-title">ایران 🇮🇷</div></div>
      <div class="card group-card" data-group="all"><div class="card-title">هر دو 🌐🇮🇷</div></div>
    </div>

    <div class="accordion" id="limitAccordion">
      <div class="accordion-header" id="limitAccordionHeader">
        <span>📊 محدودیت تعداد</span>
        <span>▼</span>
      </div>
      <div class="accordion-content">
        <div class="cards-container" id="limitContainer">
          ${[12,24,36,45,60,100].map(l => `
            <div class="card limit-option ${l===12?'selected':''}" data-limit="${l}">
              <div class="card-title">${l===100?'همه':l}</div>
            </div>
          `).join('')}
        </div>
      </div>
    </div>

    <div class="result-container" id="resultSection">
      <div class="result-title">🔗 لینک سابسکریپشن</div>
      <div class="result-box" id="subscribeLink"></div>
      <button class="btn-copy" id="copyBtn">📋 کپی لینک</button>
    </div>
  </div>

  <script>
    let selectedPorts = [];
    let selectedGroup = 'public';
    let selectedLimit = 'all';
    let selectedProtocol = 'all';

    // رویدادهای کلیک
    document.querySelectorAll('.protocol-card').forEach(c => {
      c.addEventListener('click', function() {
        document.querySelectorAll('.protocol-card').forEach(c => c.classList.remove('selected'));
        this.classList.add('selected');
        selectedProtocol = this.dataset.protocol;
        updateResult();
      });
    });

    document.querySelectorAll('.port-card').forEach(c => {
      c.addEventListener('click', function() {
        const port = this.dataset.port;
        if (selectedPorts.includes(port)) {
          selectedPorts = selectedPorts.filter(p => p !== port);
          this.classList.remove('selected');
        } else {
          selectedPorts.push(port);
          this.classList.add('selected');
        }
        updateResult();
      });
    });

    document.querySelectorAll('.group-card').forEach(c => {
      c.addEventListener('click', function() {
        document.querySelectorAll('.group-card').forEach(c => c.classList.remove('selected'));
        this.classList.add('selected');
        selectedGroup = this.dataset.group;
        updateResult();
      });
    });

    document.querySelectorAll('.limit-option').forEach(c => {
      c.addEventListener('click', function() {
        document.querySelectorAll('.limit-option').forEach(c => c.classList.remove('selected'));
        this.classList.add('selected');
        selectedLimit = this.dataset.limit;
        updateResult();
      });
    });

    // آکاردئون‌ها
    document.getElementById('protocolAccordionHeader').addEventListener('click', function() {
      document.getElementById('protocolAccordion').classList.toggle('active');
    });
    document.getElementById('portsAccordionHeader').addEventListener('click', function() {
      document.getElementById('portsAccordion').classList.toggle('active');
    });
    document.getElementById('limitAccordionHeader').addEventListener('click', function() {
      document.getElementById('limitAccordion').classList.toggle('active');
    });

    // کپی
    document.getElementById('copyBtn').addEventListener('click', function() {
      const link = document.getElementById('subscribeLink').textContent;
      navigator.clipboard.writeText(link).then(() => {
        showAlert('✅ لینک کپی شد');
      }).catch(() => showAlert('❌ خطا در کپی'));
    });

    // خروج
    document.getElementById('logoutBtn').addEventListener('click', async function() {
      showAlert('در حال خروج...');
      await fetch('/logout', { method: 'POST' });
      setTimeout(() => window.location.href = '/', 1000);
    });

    // رفرش
    document.getElementById('refreshBtn').addEventListener('click', function() {
      window.location.reload();
    });

    // آپدیت نتیجه
    function updateResult() {
      const baseUrl = window.location.origin;
      let path = '';
      
      if (selectedGroup === 'public') path = '/public';
      else if (selectedGroup === 'iran') path = '/iran';
      else if (selectedGroup === 'all') path = '/all';

      let url = baseUrl + path;
      const params = new URLSearchParams();
      
      if (selectedPorts.length > 0) params.set('ports', selectedPorts.join(','));
      if (selectedLimit !== 'all') params.set('limit', selectedLimit);
      if (selectedProtocol !== 'all') params.set('protocol', selectedProtocol);

      const query = params.toString();
      if (query) url += '?' + query;

      document.getElementById('resultSection').style.display = 'block';
      document.getElementById('subscribeLink').textContent = url;
    }

    // نمایش پیام
    function showAlert(message) {
      const alert = document.getElementById('alert');
      alert.textContent = message;
      alert.style.display = 'block';
      setTimeout(() => alert.style.display = 'none', 4000);
    }

    // آپدیت اولیه
    updateResult();
  </script>
</body>
</html>
  `;
}

export default {
  async fetch(request) {
    return handleRequest(request);
  }
};
EOF
}

# ============================================
# نصب Worker
# ============================================

install_worker() {
    print_step "ساخت Worker جدید..."
    
    # تولید نام رندوم
    WORKER_NAME=$(generate_random_name)
    print_info "نام Worker: $WORKER_NAME"
    
    # تولید کد با پسورد رندوم
    WORKER_CODE=$(generate_worker_code)
    ADMIN_PASS=$(echo "$WORKER_CODE" | grep -o "ADMIN_PASS_PLACEHOLDER" | head -1 || echo "")
    
    # ذخیره کد در فایل موقت
    TEMP_FILE=$(mktemp)
    echo "$WORKER_CODE" > "$TEMP_FILE"
    
    # نصب Worker از طریق API
    print_step "در حال نصب روی Cloudflare..."
    
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/javascript" \
        --data-binary "@$TEMP_FILE")
    
    # حذف فایل موقت
    rm -f "$TEMP_FILE"
    
    if echo "$RESPONSE" | grep -q '"success":true'; then
        print_success "Worker با موفقیت نصب شد!"
        
        # گرفتن Subdomain
        SUBDOMAIN=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/subdomain" \
            -H "Authorization: Bearer $CF_TOKEN" \
            -H "Content-Type: application/json" | jq -r '.result.subdomain')
        
        if [ "$SUBDOMAIN" != "null" ] && [ ! -z "$SUBDOMAIN" ]; then
            WORKER_URL="https://$WORKER_NAME.$SUBDOMAIN.workers.dev"
        else
            WORKER_URL="https://$WORKER_NAME.workers.dev"
        fi
        
        print_success "✅ پنل شما با موفقیت نصب شد!"
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  🍂  لینک پنل: ${CYAN}$WORKER_URL${NC}"
        echo -e "${GREEN}║${NC}  🔑  رمز عبور: ${YELLOW}$ADMIN_PASS${NC}"
        echo -e "${GREEN}║${NC}  📝  نام Worker: ${PURPLE}$WORKER_NAME${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}⚠ رمز عبور را در جای امن ذخیره کنید!${NC}"
        echo -e "${BLUE}ℹ برای تغییر رمز، کد Worker را ویرایش کنید.${NC}"
        
        return 0
    else
        print_error "نصب ناموفق بود!"
        echo "$RESPONSE" | jq '.errors'
        return 1
    fi
}

# ============================================
# منوی اصلی
# ============================================

main_menu() {
    print_banner
    
    echo -e "${YELLOW}لطفاً یک گزینه انتخاب کنید:${NC}"
    echo ""
    echo "  1) 🚀 نصب جدید پنل"
    echo "  2) 🔄 بروزرسانی پنل موجود"
    echo "  3) 🗑️ حذف پنل"
    echo "  4) 📋 لیست پنل‌ها"
    echo "  5) ❌ خروج"
    echo ""
    read -p "گزینه (1-5): " choice
    
    case $choice in
        1)
            check_dependencies
            get_credentials
            install_worker
            ;;
        2)
            check_dependencies
            get_credentials
            update_worker
            ;;
        3)
            check_dependencies
            get_credentials
            delete_worker
            ;;
        4)
            check_dependencies
            get_credentials
            list_workers
            ;;
        5)
            echo -e "${GREEN}خداحافظ! 🍂${NC}"
            exit 0
            ;;
        *)
            print_error "گزینه نامعتبر!"
            sleep 2
            main_menu
            ;;
    esac
}

# ============================================
# توابع مدیریتی
# ============================================

list_workers() {
    print_step "دریافت لیست Workerها..."
    
    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo ""
        echo -e "${GREEN}📋 لیست Workerهای شما:${NC}"
        echo "$RESPONSE" | jq -r '.result[] | "  - \(.id)"'
        echo ""
        read -p "برای ادامه Enter بزنید..."
        main_menu
    else
        print_error "خطا در دریافت لیست!"
        main_menu
    fi
}

update_worker() {
    print_step "بروزرسانی Worker..."
    # مشابه نصب با نام موجود
    list_workers
    read -p "نام Worker برای بروزرسانی: " WORKER_NAME
    
    if [ -z "$WORKER_NAME" ]; then
        print_error "نام الزامی است!"
        main_menu
    fi
    
    WORKER_CODE=$(generate_worker_code)
    ADMIN_PASS=$(echo "$WORKER_CODE" | grep -o "ADMIN_PASS_PLACEHOLDER" | head -1)
    
    TEMP_FILE=$(mktemp)
    echo "$WORKER_CODE" > "$TEMP_FILE"
    
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/javascript" \
        --data-binary "@$TEMP_FILE")
    
    rm -f "$TEMP_FILE"
    
    if echo "$RESPONSE" | grep -q '"success":true'; then
        print_success "بروزرسانی موفقیت‌آمیز بود!"
    else
        print_error "بروزرسانی ناموفق!"
    fi
    
    main_menu
}

delete_worker() {
    list_workers
    read -p "نام Worker برای حذف: " WORKER_NAME
    
    if [ -z "$WORKER_NAME" ]; then
        print_error "نام الزامی است!"
        main_menu
    fi
    
    read -p "آیا مطمئن هستید؟ (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        main_menu
        return
    fi
    
    RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$WORKER_NAME" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$RESPONSE" | grep -q '"success":true'; then
        print_success "Worker حذف شد!"
    else
        print_error "حذف ناموفق!"
    fi
    
    main_menu
}

# ============================================
# اجرا
# ============================================

main_menu
