#!/bin/bash

# ============================================================
# 🍂 Leef Panel Deploy Script
# Version: 1.0.0
# Description: Automated installer for Leef Panel from GitHub
# Repository: https://github.com/lavateam-IR/leef-panel
# ============================================================

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================
# FUNCTIONS
# ============================================================

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║           🍂 LEEF PANEL INSTALLER v1.0                  ║"
    echo "║                                                          ║"
    echo "║     V2Ray Config Generator Panel for Termux              ║"
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
    else
        print_success "$1 found"
        return 0
    fi
}

# ============================================================
# MAIN SCRIPT
# ============================================================

print_header

print_step "Checking system requirements..."

# Check for required tools
MISSING=0
check_command "curl" || MISSING=1
check_command "bash" || MISSING=1

if [ $MISSING -eq 1 ]; then
    print_error "Missing required packages. Please install them first."
    print_info "For Termux: pkg install curl bash"
    exit 1
fi

print_step "Downloading Leef Panel from GitHub..."

REPO_URL="https://raw.githubusercontent.com/lavateam-IR/leef-panel/main/leef.sh"
TEMP_SCRIPT="/tmp/leef_panel_install.sh"

# Download the script
print_info "Fetching latest version from: $REPO_URL"
curl -sSL -o "$TEMP_SCRIPT" "$REPO_URL"

if [ $? -ne 0 ] || [ ! -f "$TEMP_SCRIPT" ]; then
    print_error "Failed to download the panel script."
    print_info "Please check your internet connection and try again."
    exit 1
fi

print_success "Script downloaded successfully"

# Make it executable
chmod +x "$TEMP_SCRIPT"

print_step "Starting Leef Panel installation..."

# Execute the downloaded script
bash "$TEMP_SCRIPT"

# Check if installation was successful
if [ $? -eq 0 ]; then
    print_success "Leef Panel installed successfully!"
else
    print_error "Installation failed."
    exit 1
fi

# Clean up
rm -f "$TEMP_SCRIPT"

print_step "Installation Complete!"

echo -e "\n${GREEN}${BOLD}✅ Leef Panel is ready to use!${NC}"
echo -e "\n${YELLOW}${BOLD}ℹ️  You can now run the panel by typing:${NC}"
echo -e "   ${BOLD}bash leef.sh${NC}"
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${GREEN}${BOLD}Thank you for using Leef Panel! 🍂${NC}\n"
