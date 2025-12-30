#!/bin/bash

BUN_DIR="/usr/local/bun"
GO_DIR="/usr/local/go"
export NVM_DIR="/home/container/.nvm"
export PLAYWRIGHT_BROWSERS_PATH="/usr/local/share/playwright"

# Install NVM if not present
if [ ! -d "$NVM_DIR" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# Source NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Setup PATH and bashrc
export PATH="$BUN_DIR/bin:$GO_DIR/bin:$PATH"

cat > /home/container/.bashrc << 'EOF'
export NVM_DIR="/home/container/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export PATH="/usr/local/bun/bin:/usr/local/go/bin:$PATH"
export PLAYWRIGHT_BROWSERS_PATH="/usr/local/share/playwright"
EOF

# Install Node.js via NVM
if [ ! -z "${NODE_VERSION}" ]; then
    CURRENT_VER=$(node -v 2>/dev/null || echo "none")
    
    # Check if we need to install/switch version
    if ! nvm ls "${NODE_VERSION}" > /dev/null 2>&1; then
        echo "Installing Node.js ${NODE_VERSION} via NVM..."
        nvm install "${NODE_VERSION}"
    fi
    
    nvm use "${NODE_VERSION}"
    
    # Install global packages if pm2 is not present
    if ! command -v pm2 &> /dev/null; then
        echo "Installing global npm packages..."
        npm install -g npm@latest pm2 pnpm yarn playwright --loglevel=error
    fi
elif [ -f ".nvmrc" ]; then
    # Auto-detect version from .nvmrc if present
    echo "Found .nvmrc, installing specified version..."
    nvm install
    nvm use
    if ! command -v pm2 &> /dev/null; then
        npm install -g npm@latest pm2 pnpm yarn playwright --loglevel=error
    fi
fi

if [[ "${ENABLE_CF_TUNNEL}" == "true" ]] || [[ "${ENABLE_CF_TUNNEL}" == "1" ]]; then
    if [ ! -z "${CF_TOKEN}" ]; then
        pkill -f cloudflared 2>/dev/null
        nohup cloudflared tunnel run --token ${CF_TOKEN} > /home/container/.cloudflared.log 2>&1 &
    fi
fi

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_WHITE='\033[97m'

# Helper function for progress bar
progress_bar() {
    local percent=$1
    local width=20
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done
    
    if [ $percent -lt 50 ]; then
        echo -e "${C_GREEN}[${bar}]${C_RESET}"
    elif [ $percent -lt 80 ]; then
        echo -e "${C_YELLOW}[${bar}]${C_RESET}"
    else
        echo -e "\033[31m[${bar}]${C_RESET}"
    fi
}

# Gather system info
LOCATION=$(curl -s ipinfo.io/country 2>/dev/null || echo 'Unknown')
OS_NAME=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
UPTIME_STR=$(uptime -p | sed 's/up //')

RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))

DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

# Runtime versions
NODE_VER=$(node -v 2>/dev/null || echo 'Not Installed')
BUN_VER=$(bun -v 2>/dev/null) && BUN_VER="v${BUN_VER}" || BUN_VER='Not Installed'
GO_VER=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go/v/' || echo 'Not Installed')
PYTHON_VER=$(python3 --version 2>/dev/null | awk '{print "v"$2}' || echo 'Not Installed')
PLAYWRIGHT_VER=$(playwright --version 2>/dev/null | head -n 1 || echo 'Not Installed')

clear
echo ""
echo -e "${C_CYAN}${C_BOLD}    ___  __  __ ___     ___"
echo -e "   | _ \\|  \\/  |__ )   | __|__ _ __ _"
echo -e "   |  _/| |\\/| |/ /    | _|/ _\` / _\` |"
echo -e "   |_|  |_|  |_|/___|  |___\\__, \\__, |"
echo -e "                          |___/|___/${C_RESET}"
echo ""
echo -e "${C_DIM}==============================================================${C_RESET}"
echo -e "${C_WHITE}${C_BOLD}                         SYSTEM${C_RESET}"
echo -e "${C_DIM}==============================================================${C_RESET}"
echo -e "  ${C_CYAN}Location${C_RESET}    : ${C_WHITE}${LOCATION}${C_RESET}"
echo -e "  ${C_CYAN}OS${C_RESET}          : ${C_WHITE}${OS_NAME}${C_RESET}"
echo -e "  ${C_CYAN}CPU${C_RESET}         : ${C_WHITE}${CPU_MODEL} ${C_DIM}(${CPU_CORES} Cores)${C_RESET}"
echo -e "  ${C_CYAN}Uptime${C_RESET}      : ${C_WHITE}${UPTIME_STR}${C_RESET}"
echo ""
echo -e "${C_DIM}==============================================================${C_RESET}"
echo -e "${C_WHITE}${C_BOLD}                        RESOURCES${C_RESET}"
echo -e "${C_DIM}==============================================================${C_RESET}"
echo -e "  ${C_CYAN}RAM${C_RESET}         : $(progress_bar $RAM_PERCENT) ${C_WHITE}${RAM_USED}MB${C_DIM}/${RAM_TOTAL}MB${C_RESET}"
echo -e "  ${C_CYAN}Disk${C_RESET}        : $(progress_bar $DISK_PERCENT) ${C_WHITE}${DISK_USED}${C_DIM}/${DISK_TOTAL}${C_RESET}"
echo ""
echo -e "${C_DIM}==============================================================${C_RESET}"
echo -e "${C_WHITE}${C_BOLD}                        RUNTIMES${C_RESET}"
echo -e "${C_DIM}==============================================================${C_RESET}"
echo -e "  ${C_GREEN}Node.js${C_RESET}     : ${C_WHITE}${NODE_VER}${C_RESET}"
echo -e "  ${C_YELLOW}Bun${C_RESET}         : ${C_WHITE}${BUN_VER}${C_RESET}"
echo -e "  ${C_CYAN}Go${C_RESET}          : ${C_WHITE}${GO_VER}${C_RESET}"
echo -e "  ${C_CYAN}Python${C_RESET}      : ${C_WHITE}${PYTHON_VER}${C_RESET}"
echo -e "  ${C_CYAN}Playwright${C_RESET}  : ${C_WHITE}${PLAYWRIGHT_VER}${C_RESET}"
echo -e "${C_DIM}==============================================================${C_RESET}"
echo ""

exec /bin/bash
