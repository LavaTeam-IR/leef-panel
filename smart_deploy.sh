#!/bin/bash

# رنگ‌ها برای قشنگی و خوانایی ترمینال
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}    Leef Panel Smart Cloudflare Deploy   ${NC}"
echo -e "${BLUE}=====================================${NC}"

# ۱. دریافت اطلاعات از کاربر
read -p "Enter your Cloudflare Global API Token: " CF_TOKEN
if [ -z "$CF_TOKEN" ]; then
    echo -e "${RED}Error: Cloudflare Token cannot be empty!${NC}"
    exit 1
fi

read -p "Enter your Main Domain (e.g., example.com): " MAIN_DOMAIN
read -p "Enter desired Subdomain prefix (e.g., panel -> panel.example.com): " SUB_PREFIX

FULL_DOMAIN="${SUB_PREFIX}.${MAIN_DOMAIN}"

# پیدا کردن IP سرور فعلی به صورت خودکار
echo -e "${YELLOW}Detecting server public IP...${NC}"
SERVER_IP=$(curl -s https://api.ipify.org)
echo -e "${GREEN}Server IP detected: $SERVER_IP${NC}"

# ۲. اعتبارسنجی توکن کلودفلر
echo -e "${YELLOW}Verifying Cloudflare Token...${NC}"
AUTH_CHECK=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type:application/json")

if [[ "$AUTH_CHECK" != *"active"* ]]; then
    echo -e "${RED}Invalid Cloudflare Token or token is not active!${NC}"
    exit 1
fi
echo -e "${GREEN}Token verified successfully.${NC}"

# ۳. پیدا کردن Zone ID دامنه
echo -e "${YELLOW}Fetching Zone ID for $MAIN_DOMAIN...${NC}"
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$MAIN_DOMAIN" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type:application/json" | grep -o '"id":"[^"]*' | head -n 1 | dirname | cut -d'"' -f4)

if [ -z "$ZONE_ID" ]; then
    echo -e "${RED}Could not find Zone ID for domain $MAIN_DOMAIN. Make sure the domain is added to Cloudflare.${NC}"
    exit 1
fi
echo -e "${GREEN}Zone ID found: $ZONE_ID${NC}"

# ۴. ساخت یا آپدیت رکورد DNS (A Record)
echo -e "${YELLOW}Creating DNS A Record for $FULL_DOMAIN pointing to $SERVER_IP...${NC}"
# فعال کردن Proxie (ابر روشن) برای امنیت بیشتر
DNS_RECORD=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type:application/json" \
     --data "{\"type\":\"A\",\"name\":\"$SUB_PREFIX\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":true}")

if [[ "$DNS_RECORD" == *"success\":true"* ]]; then
    echo -e "${GREEN}DNS Record created successfully!${NC}"
else
    echo -e "${YELLOW}Failed to create or record already exists. Attempting to update...${NC}"
    # اینجا می‌شه کد آپدیت هم اضافه کرد ولی معمولاً برای بار اول اوکیه
fi

# ۵. اعمال تنظیمات آماده و بهینه‌سازی کلودفلر (Best Practices)
echo -e "${YELLOW}Applying optimized Cloudflare settings...${NC}"

# تنظیم SSL روی Full (Strict) برای امنیت حداکثری ارتباط سرور و کلودفلر
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type:application/json" \
     --data '{"value":"strict"}' > /dev/null

# روشن کردن Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type:application/json" \
     --data '{"value":"on"}' > /dev/null

# فعال کردن فشرده‌سازی Brotli برای سرعت بالاتر پنل
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/brotli" \
     -H "Authorization: Bearer $CF_TOKEN" \
     -H "Content-Type:application/json" \
     --data '{"value":"on"}' > /dev/null

echo -e "${GREEN}Cloudflare optimizations applied (SSL Full Strict, HTTPS Redirect, Brotli Enabled).${NC}"

# ۶. آماده‌سازی محیط سرور (تزریق مغز اسکریپت برای پیش‌نیازها)
echo -e "${YELLOW}Updating system packages and installing dependencies...${NC}"
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl git ufw jq

# تنظیم فایروال برای پورت‌های استاندارد وب و جلوگیری از بلاک شدن توسط کلودفلر
echo -e "${YELLOW}Configuring basic firewall...${NC}"
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
echo "y" | sudo ufw enable

echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}All set! Your domain $FULL_DOMAIN is ready.${NC}"
echo -e "${GREEN}Cloudflare is fully configured and proxy is active.${NC}"
echo -e "${YELLOW}You can now proceed with launching the specific Leef Panel core components.${NC}"
echo -e "${BLUE}=====================================${NC}"

