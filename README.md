# HP lt4120 Snapdragon X5 LTE Modem - Linux Setup

Automated setup script for getting the HP lt4120 Snapdragon X5 LTE modem working on Linux. This modem is commonly found in HP ProBook 640 G2 laptops and doesn't work out-of-the-box on most Linux distributions.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/waheed-phy/hp-lt4120-linux-setup.git
cd hp-lt4120-linux-setup

# Run the setup script
sudo bash hp-lt4120-setup.sh
```

That's it! The script will automatically:
- Detect your Linux distribution
- Install required packages
- Configure the modem
- Set up automatic configuration on boot

## 📋 Prerequisites

- HP ProBook 640 G2 (or similar) with HP lt4120 LTE modem
- Active SIM card inserted
- Root/sudo access
- Internet connection for initial setup

## 🐧 Supported Distributions

The script has been tested and supports:

- **Debian-based**: Debian, Ubuntu, Linux Mint, Pop!_OS
- **Red Hat-based**: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
- **Arch-based**: Arch Linux, Manjaro, EndeavourOS
- **SUSE-based**: openSUSE Leap/Tumbleweed
- **Gentoo**
- Other distributions (with manual package installation)

## 🔧 What the Script Does

1. **Auto-detects** your Linux distribution
2. **Installs** required packages (ModemManager, NetworkManager, libqmi-utils, usb-modeswitch)
3. **Verifies** the modem hardware is present
4. **Loads** necessary kernel modules
5. **Configures** the modem to use MBIM interface (USB configuration 3)
6. **Creates** a persistent startup script
7. **Sets up** a systemd service for automatic configuration on boot
8. **Enables** the modem and displays status

## 📖 Manual Installation

If you prefer to understand what's happening, check out the [MANUAL_SETUP.md](MANUAL_SETUP.md) guide for detailed step-by-step instructions.

## 🔍 Verifying the Modem

After running the script, verify your modem is working:

```bash
# List detected modems
mmcli -L

# Check modem status
mmcli -m 0

# Check SIM status
mmcli -i 0
```

## 🔐 If Your SIM Has a PIN

If your SIM card requires a PIN:

```bash
mmcli -i 0 --pin=YOUR_PIN_HERE
```

To automatically unlock on boot, edit `/usr/local/bin/hp-lt4120-startup.sh` and add:
```bash
sleep 5
mmcli -i 0 --pin=YOUR_PIN_HERE
```

## 🌐 Connecting to the Internet

### Using NetworkManager GUI
1. Open your network settings
2. Look for "Mobile Broadband" or "Cellular"
3. Add a new connection with your carrier's APN

### Using nmtui (Terminal UI)
```bash
nmtui
```
Navigate to "Edit a connection" and configure mobile broadband.

### Using nmcli (Command Line)
```bash
# Create connection (replace 'internet' with your carrier's APN)
sudo nmcli connection add type gsm ifname wwp0s20f0u3c3 con-name cellular apn internet

# Connect
sudo nmcli connection up cellular

# Disconnect
sudo nmcli connection down cellular
```

## 🛠️ Troubleshooting

### Modem not detected after reboot

```bash
# Check service status
sudo systemctl status hp-lt4120.service

# Manually run the setup script
sudo /usr/local/bin/hp-lt4120-startup.sh

# Check if modem is visible in USB
lsusb | grep HP
```

### No internet connection

```bash
# Check if modem is enabled
mmcli -m 0

# Check bearer status
mmcli -b 0

# Check network interface
ip addr show

# Try reconnecting
sudo nmcli connection down cellular
sudo nmcli connection up cellular
```

### Configuration not persisting

The systemd service should handle this automatically. If issues persist:

```bash
# Check if service is enabled
sudo systemctl is-enabled hp-lt4120.service

# Re-enable service
sudo systemctl enable hp-lt4120.service

# Check service logs
sudo journalctl -u hp-lt4120.service
```

### PIN required every boot

Edit the startup script to include PIN unlock:
```bash
sudo nano /usr/local/bin/hp-lt4120-startup.sh
```

Add after the configuration switch:
```bash
sleep 5
mmcli -i 0 --pin=YOUR_PIN_HERE
```

## 📱 Known Working Carriers

This modem has been confirmed working with:
- Verizon (US)
- AT&T (US)
- T-Mobile (US)
- Various European carriers

If you've tested with other carriers, please let us know!

## 🤝 Contributing

Contributions are welcome! If you've tested this on a different distribution or have improvements:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add some improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request

## 📝 Useful Commands

```bash
# List all modems
mmcli -L

# Get detailed modem info
mmcli -m 0

# Get SIM info
mmcli -i 0

# Enable modem
sudo mmcli -m 0 --enable

# Disable modem
sudo mmcli -m 0 --disable

# Check USB configuration
cat /sys/bus/usb/devices/*/bConfigurationValue

# Monitor ModemManager logs
sudo journalctl -f -u ModemManager

# Check network interfaces
ip link show | grep ww
```

## 🔬 Technical Details

The HP lt4120 modem has three USB configurations:
1. **Configuration 1**: Multiple vendor-specific interfaces (doesn't work)
2. **Configuration 2**: CDC Ethernet (doesn't work for cellular)
3. **Configuration 3**: MBIM interface (this is what we need!)

The modem defaults to configuration 1, which isn't compatible with ModemManager. This script switches it to configuration 3 (MBIM) and ensures this configuration is applied on every boot.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Created based on successful troubleshooting on Debian 13
- Thanks to the ModemManager and libqmi projects
- Community contributions and testing

## ⚠️ Disclaimer

This script modifies system files and USB device configurations. While it has been tested on multiple systems, use it at your own risk. Always ensure you have backups of important data.

## 📧 Support

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review existing [Issues](https://github.com/waheed-phy/hp-lt4120-linux-setup/issues)
3. Open a new issue with:
   - Your Linux distribution and version
   - Output of `lsusb | grep HP`
   - Output of `mmcli -L`
   - Any error messages

---

**Star ⭐ this repository if it helped you!**
