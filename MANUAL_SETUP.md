# HP ProBook 640 G2 LTE Modem (HP lt4120) Linux Setup Guide

This guide will help you get the HP lt4120 Snapdragon X5 LTE modem working on Linux systems, specifically tested on Debian 13 but should work on most modern Linux distributions.

## Problem Description

The HP ProBook 640 G2 comes with an HP lt4120 Snapdragon X5 LTE modem that doesn't work out-of-the-box on most Linux distributions. The modem is detected but ModemManager can't communicate with it properly.

## Prerequisites

- HP ProBook 640 G2 with HP lt4120 LTE modem
- Active SIM card inserted
- Root/sudo access
- Internet connection (for initial setup)

## Step 1: Verify Your Hardware

First, let's confirm you have the correct hardware:

```bash
lsusb | grep HP
```

**Expected Output:**
```
Bus 001 Device 002: ID 03f0:9d1d HP, Inc HP lt4120 Snapdragon X5 LTE
```

**If you don't see this output:**
- Your laptop doesn't have the LTE modem, or
- The modem is disabled in BIOS, or  
- You have a different model

## Step 2: Install Required Software

Install the necessary packages:

```bash
sudo apt update
sudo apt install modemmanager network-manager libqmi-utils
```

## Step 3: Check Current Modem Status

Check if ModemManager can detect the modem:

```bash
mmcli -L
```

**Possible Outputs:**

**A) "No modems were found"** - This is the expected result initially. Continue to Step 4.

**B) Shows a modem** - Skip to Step 8 to check if it's working properly.

## Step 4: Check USB Modules

Verify the required kernel modules are loaded:

```bash
lsmod | grep -E "(cdc_wdm|qmi_wwan)"
```

**Expected Output:**
```
qmi_wwan               40960  0
cdc_wdm                32768  1 qmi_wwan
usbnet                 65536  2 qmi_wwan,cdc_ether
```

**If modules are missing:**
```bash
sudo modprobe cdc_wdm
sudo modprobe qmi_wwan
```

## Step 5: Examine USB Configuration

Check the detailed USB information:

```bash
lsusb -v -d 03f0:9d1d
```

Look for the section that shows **bNumConfigurations**. The HP lt4120 has 3 configurations:
- Configuration 1: Multiple vendor-specific interfaces (doesn't work)
- Configuration 2: CDC Ethernet (doesn't work for cellular)  
- Configuration 3: MBIM interface (this is what we need)

## Step 6: Find the USB Device Path

Find the exact system path for your modem:

```bash
for dev in /sys/bus/usb/devices/[0-9]*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        vendor=$(cat "$dev/idVendor" 2>/dev/null)
        product=$(cat "$dev/idProduct" 2>/dev/null)
        if [ "$vendor" = "03f0" ] && [ "$product" = "9d1d" ]; then
            echo "Found device at: $dev"
            echo "Current configuration: $(cat $dev/bConfigurationValue 2>/dev/null)"
        fi
    fi
done
```

**Expected Output:**
```
Found device at: /sys/bus/usb/devices/1-3
Current configuration: 
```

**Note the path** (e.g., `/sys/bus/usb/devices/1-3`) - you'll need it for the next step.

## Step 7: Switch USB Configuration

Switch the modem to configuration 3 (replace `1-3` with your actual device path from Step 6):

```bash
echo 3 | sudo tee /sys/bus/usb/devices/1-3/bConfigurationValue
```

**Expected Output:**
```
3
```

Verify the change:
```bash
cat /sys/bus/usb/devices/1-3/bConfigurationValue
```

**Expected Output:**
```
3
```

## Step 8: Restart ModemManager

Restart ModemManager to detect the properly configured modem:

```bash
sudo systemctl restart ModemManager
sleep 5
```

## Step 9: Verify Modem Detection

Check if the modem is now detected:

```bash
mmcli -L
```

**Expected Output:**
```
/org/freedesktop/ModemManager1/Modem/0 [HP] HP lt4120 Snapdragon X5 LTE
```

**If still "No modems were found":**
1. Double-check the USB configuration value from Step 7
2. Try unplugging and replugging the laptop (if removable modem)
3. Reboot and repeat from Step 6

## Step 10: Check Modem Details

Get detailed modem information:

```bash
mmcli -m 0
```

Look for these key fields in the output:
- **state**: Should show "disabled" initially, then "connected" after enabling
- **lock**: May show "sim-pin2" or "none"  
- **primary port**: Should show "cdc-wdm0"
- **drivers**: Should show "cdc_mbim"

## Step 11: Enable the Modem

Enable the modem for use:

```bash
mmcli -m 0 --enable
```

**Possible Outputs:**

**A) Success** - No error message, modem enables successfully.

**B) PIN required** - If your SIM has a PIN:
```bash
mmcli -i 0 --pin=YOUR_PIN_HERE
```

## Step 12: Check SIM Status

Verify SIM card details:

```bash
mmcli -i 0
```

**Expected Output:**
```
Properties |            active: yes
           |              imsi: [your IMSI number]
           |             iccid: [your ICCID number]
```

## Step 13: Verify Connection

Check final modem status:

```bash
mmcli -m 0
```

Look for these indicators of success:
- **state**: "connected"
- **access tech**: "lte" (or "gsm", "umts")
- **signal quality**: A percentage value
- **operator name**: Your carrier name
- **registration**: "home" or "roaming"

## Step 14: Test Internet Connectivity

Check the network interface:

```bash
ip link show | grep ww
```

You should see an interface like `wwp0s20f0u3c3`.

Test connectivity:
```bash
ping -c 3 8.8.8.8
```

## Making It Permanent

The USB configuration change will be lost on reboot. To make it permanent:

### Method 1: Create Setup Script

1. Create the setup script:
```bash
sudo nano /usr/local/bin/hp-lt4120-setup.sh
```

2. Add this content:
```bash
#!/bin/bash
# HP lt4120 LTE Modem Setup Script
sleep 2

echo "Setting up HP lt4120 LTE modem..."

for dev in /sys/bus/usb/devices/[0-9]*-*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        vendor=$(cat "$dev/idVendor" 2>/dev/null)
        product=$(cat "$dev/idProduct" 2>/dev/null)
        if [ "$vendor" = "03f0" ] && [ "$product" = "9d1d" ]; then
            echo "Found HP lt4120 at $dev"
            echo 3 > "$dev/bConfigurationValue"
            echo "Switched to configuration 3"
            sleep 3
            systemctl restart ModemManager
            echo "ModemManager restarted"
            break
        fi
    fi
done
```

3. Make it executable:
```bash
sudo chmod +x /usr/local/bin/hp-lt4120-setup.sh
```

### Method 2: Create Systemd Service

1. Create the service file:
```bash
sudo nano /etc/systemd/system/hp-lt4120.service
```

2. Add this content:
```ini
[Unit]
Description=HP lt4120 LTE Modem Setup
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hp-lt4120-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

3. Enable the service:
```bash
sudo systemctl enable hp-lt4120.service
```

## Testing the Permanent Setup

Reboot your system:
```bash
sudo reboot
```

After reboot, verify everything is working:
```bash
# Wait a moment after login, then check:
mmcli -L
mmcli -m 0
```

## Troubleshooting

### Issue: "No modems were found" after reboot

**Solution:**
1. Check if the service is running:
   ```bash
   sudo systemctl status hp-lt4120.service
   ```
2. Manually run the setup script:
   ```bash
   sudo /usr/local/bin/hp-lt4120-setup.sh
   ```
3. Check the device path hasn't changed:
   ```bash
   lsusb | grep HP
   ```

### Issue: Modem detected but no internet

**Solution:**
1. Check bearer status:
   ```bash
   mmcli -b 0
   ```
2. Check network interface:
   ```bash
   ip addr show
   ```
3. Try connecting with NetworkManager GUI or `nmtui`

### Issue: PIN required every boot

**Solution:**
Add PIN unlock to the setup script:
```bash
# Add after the ModemManager restart line:
sleep 5
mmcli -i 0 --pin=YOUR_PIN_HERE
```

### Issue: Works sometimes, not always

**Solution:**
This usually indicates timing issues. Increase the sleep values in the setup script:
```bash
# Change sleep 2 to sleep 5
# Change sleep 3 to sleep 5
```

## Using the Connection

### With NetworkManager GUI
1. Open Network Settings
2. Look for "Mobile Broadband" or "Cellular"
3. Configure your APN settings if needed

### With nmtui (Terminal UI)
```bash
nmtui
```
Navigate to "Edit a connection" and set up mobile broadband.

### With nmcli (Command Line)
```bash
# Create connection (replace APN with your carrier's APN)
sudo nmcli connection add type gsm ifname wwp0s20f0u3c3 con-name cellular apn internet

# Connect
sudo nmcli connection up cellular
```

## Notes

- This guide is specifically for the HP ProBook 640 G2 with HP lt4120 modem
- The device path (`1-3` in examples) may vary on your system
- Some carriers may require specific APN settings
- Signal strength depends on your location and carrier coverage

## Credits

This guide was created based on successful troubleshooting of the HP lt4120 modem on Debian 13. The key insight is that the modem needs to be switched from the default multi-interface configuration to the MBIM configuration for proper Linux support.
