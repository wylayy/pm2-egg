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

clear
echo "----------------------------------------------------------"
echo "                    ATHARS CLOUD SYSTEM                   "
echo "----------------------------------------------------------"
echo "Location   : $(curl -s ipinfo.io/country 2>/dev/null || echo 'Unknown')"
echo "OS         : $(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '\"')"
echo "CPU        : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //') ($(( $(grep -c ^processor /proc/cpuinfo) )) Cores)"
echo "Uptime     : $(uptime -p | sed 's/up //')"
echo ""
echo "RAM Usage  : $(free -m | awk '/Mem:/ {print $3" MB / "$2" MB"}')"
echo "Disk Usage : $(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')"
echo "----------------------------------------------------------"
echo "                     RUNTIME VERSIONS                     "
echo "----------------------------------------------------------"
echo "Node.js    : $(node -v 2>/dev/null || echo 'Not Installed')"
echo "Bun        : v$(bun -v 2>/dev/null || echo 'Not Installed')"
echo "Golang     : v$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo 'Not Installed')"
echo "Python     : v$(python3 --version 2>/dev/null | awk '{print $2}' || echo 'Not Installed')"
echo "Playwright : $(playwright --version 2>/dev/null | head -n 1 || echo 'Not Installed')"
echo "----------------------------------------------------------"

exec /bin/bash
