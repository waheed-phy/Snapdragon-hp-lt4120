#!/bin/bash

# HP lt4120 Snapdragon X5 LTE Modem Setup Script
# Automatically configures the HP lt4120 modem for Linux
# Compatible with most modern Linux distributions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}HP lt4120 LTE Modem Setup Script${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        echo -e "${GREEN}Detected distribution: $PRETTY_NAME${NC}\n"
    else
        echo -e "${YELLOW}Warning: Could not detect distribution, assuming Debian-based${NC}\n"
        DISTRO="debian"
    fi
}

# Install required packages based on distribution
install_packages() {
    echo -e "${BLUE}Step 1: Installing required packages...${NC}"
    
    case $DISTRO in
        debian|ubuntu|linuxmint|pop)
            apt-get update
            apt-get install -y modemmanager network-manager libqmi-utils usb-modeswitch
            ;;
        fedora|rhel|centos|rocky|almalinux)
            dnf install -y ModemManager NetworkManager libqmi-utils usb_modeswitch
            ;;
        arch|manjaro|endeavouros)
            pacman -Sy --noconfirm modemmanager networkmanager libqmi usb_modeswitch
            ;;
        opensuse*|suse)
            zypper install -y ModemManager NetworkManager libqmi-tools usb_modeswitch
            ;;
        gentoo)
            emerge --ask=n net-misc/modemmanager net-misc/networkmanager net-libs/libqmi sys-apps/usb_modeswitch
            ;;
        *)
            echo -e "${YELLOW}Warning: Unknown distribution. Please install manually:${NC}"
            echo "  - modemmanager"
            echo "  - network-manager"
            echo "  - libqmi-utils"
            echo "  - usb-modeswitch"
            read -p "Press Enter to continue after installing packages..."
            ;;
    esac
    
    echo -e "${GREEN}✓ Packages installed${NC}\n"
}

# Verify hardware presence
verify_hardware() {
    echo -e "${BLUE}Step 2: Verifying HP lt4120 modem presence...${NC}"
    
    if lsusb | grep -q "03f0:9d1d"; then
        echo -e "${GREEN}✓ HP lt4120 modem detected${NC}"
        lsusb | grep "03f0:9d1d"
        echo ""
    else
        echo -e "${RED}✗ HP lt4120 modem not found${NC}"
        echo -e "${YELLOW}Please check:${NC}"
        echo "  1. Modem is installed in the laptop"
        echo "  2. Modem is enabled in BIOS"
        echo "  3. SIM card is inserted"
        exit 1
    fi
}

# Load required kernel modules
load_modules() {
    echo -e "${BLUE}Step 3: Loading kernel modules...${NC}"
    
    modprobe cdc_wdm 2>/dev/null || echo -e "${YELLOW}cdc_wdm already loaded${NC}"
    modprobe qmi_wwan 2>/dev/null || echo -e "${YELLOW}qmi_wwan already loaded${NC}"
    modprobe cdc_mbim 2>/dev/null || echo -e "${YELLOW}cdc_mbim already loaded${NC}"
    
    if lsmod | grep -qE "(cdc_wdm|qmi_wwan|cdc_mbim)"; then
        echo -e "${GREEN}✓ Kernel modules loaded${NC}\n"
    else
        echo -e "${RED}✗ Failed to load kernel modules${NC}\n"
        exit 1
    fi
}

# Find and configure the modem
configure_modem() {
    echo -e "${BLUE}Step 4: Finding and configuring modem...${NC}"
    
    DEVICE_PATH=""
    
    for dev in /sys/bus/usb/devices/[0-9]*-*; do
        if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
            vendor=$(cat "$dev/idVendor" 2>/dev/null)
            product=$(cat "$dev/idProduct" 2>/dev/null)
            if [ "$vendor" = "03f0" ] && [ "$product" = "9d1d" ]; then
                DEVICE_PATH="$dev"
                break
            fi
        fi
    done
    
    if [ -z "$DEVICE_PATH" ]; then
        echo -e "${RED}✗ Could not find modem device path${NC}\n"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Found modem at: $DEVICE_PATH${NC}"
    
    current_config=$(cat "$DEVICE_PATH/bConfigurationValue" 2>/dev/null || echo "unknown")
    echo -e "Current configuration: $current_config"
    
    if [ "$current_config" != "3" ]; then
        echo -e "${YELLOW}Switching to configuration 3 (MBIM)...${NC}"
        echo 3 > "$DEVICE_PATH/bConfigurationValue"
        sleep 2
        
        new_config=$(cat "$DEVICE_PATH/bConfigurationValue" 2>/dev/null)
        if [ "$new_config" = "3" ]; then
            echo -e "${GREEN}✓ Successfully switched to configuration 3${NC}\n"
        else
            echo -e "${RED}✗ Failed to switch configuration${NC}\n"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Already in configuration 3${NC}\n"
    fi
}

# Restart ModemManager
restart_modemmanager() {
    echo -e "${BLUE}Step 5: Restarting ModemManager...${NC}"
    
    systemctl restart ModemManager
    sleep 5
    
    if systemctl is-active --quiet ModemManager; then
        echo -e "${GREEN}✓ ModemManager restarted successfully${NC}\n"
    else
        echo -e "${RED}✗ ModemManager failed to start${NC}\n"
        exit 1
    fi
}

# Verify modem detection
verify_modem() {
    echo -e "${BLUE}Step 6: Verifying modem detection...${NC}"
    
    if mmcli -L | grep -q "Modem"; then
        echo -e "${GREEN}✓ Modem detected by ModemManager${NC}"
        mmcli -L
        echo ""
    else
        echo -e "${RED}✗ Modem not detected by ModemManager${NC}"
        echo -e "${YELLOW}Try rebooting and running this script again${NC}\n"
        exit 1
    fi
}

# Create persistent setup script
create_persistent_script() {
    echo -e "${BLUE}Step 7: Creating persistent setup script...${NC}"
    
    cat > /usr/local/bin/hp-lt4120-startup.sh << 'EOF'
#!/bin/bash
# HP lt4120 LTE Modem Startup Script
# Automatically runs at boot to configure the modem

sleep 3

for dev in /sys/bus/usb/devices/[0-9]*-*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        vendor=$(cat "$dev/idVendor" 2>/dev/null)
        product=$(cat "$dev/idProduct" 2>/dev/null)
        if [ "$vendor" = "03f0" ] && [ "$product" = "9d1d" ]; then
            current_config=$(cat "$dev/bConfigurationValue" 2>/dev/null)
            if [ "$current_config" != "3" ]; then
                echo 3 > "$dev/bConfigurationValue"
                sleep 3
                systemctl restart ModemManager
            fi
            break
        fi
    fi
done
EOF
    
    chmod +x /usr/local/bin/hp-lt4120-startup.sh
    echo -e "${GREEN}✓ Startup script created${NC}\n"
}

# Create systemd service
create_systemd_service() {
    echo -e "${BLUE}Step 8: Creating systemd service...${NC}"
    
    cat > /etc/systemd/system/hp-lt4120.service << 'EOF'
[Unit]
Description=HP lt4120 LTE Modem Configuration
After=multi-user.target
Before=ModemManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hp-lt4120-startup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable hp-lt4120.service
    
    echo -e "${GREEN}✓ Systemd service created and enabled${NC}\n"
}

# Enable modem
enable_modem() {
    echo -e "${BLUE}Step 9: Enabling modem...${NC}"
    
    mmcli -m 0 --enable 2>/dev/null || true
    sleep 3
    
    echo -e "${GREEN}✓ Modem enable command sent${NC}\n"
}

# Display final status
show_status() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}Final Status${NC}"
    echo -e "${BLUE}=====================================${NC}\n"
    
    echo -e "${YELLOW}Modem Information:${NC}"
    mmcli -m 0 2>/dev/null || echo -e "${RED}Could not retrieve modem info${NC}"
    
    echo -e "\n${YELLOW}SIM Information:${NC}"
    mmcli -i 0 2>/dev/null || echo -e "${YELLOW}SIM info not available (PIN may be required)${NC}"
    
    echo -e "\n${GREEN}=====================================${NC}"
    echo -e "${GREEN}Setup Complete!${NC}"
    echo -e "${GREEN}=====================================${NC}\n"
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. If PIN is required: mmcli -i 0 --pin=YOUR_PIN"
    echo "2. Configure connection using NetworkManager GUI or nmtui"
    echo "3. Reboot to test persistent configuration"
    echo ""
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  - Check modem status: mmcli -m 0"
    echo "  - Check SIM status: mmcli -i 0"
    echo "  - List modems: mmcli -L"
    echo "  - View service status: systemctl status hp-lt4120.service"
    echo ""
}

# Main execution
main() {
    detect_distro
    install_packages
    verify_hardware
    load_modules
    configure_modem
    restart_modemmanager
    verify_modem
    create_persistent_script
    create_systemd_service
    enable_modem
    show_status
}

# Run main function
main