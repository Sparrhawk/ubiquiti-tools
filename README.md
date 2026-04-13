# 🛠️ Ubiquiti Tools

**Schedule switch‑port enable / disable on Ubiquiti Dream Machine devices (UDM, UDM‑Pro, UDM‑SE, etc.)**

Please be aware this is entirely untested and it is created as a proposed solution to the issues reported with the UI wifi scheduling, with potential other applications. 

Perhaps: Handy for parents, school labs, or anyone who wants time‑based control over PoE ports and the devices plugged into them — Wi‑Fi access points, cameras, switches, and more.

---

## 📦 What's Included

| File | Description |
|------|-------------|
| `port-scheduler.sh` | Main script — enables or disables a list of switch ports via the UniFi controller API. |
| `find-devices.sh` | Helper script — discovers all switches on your UniFi network and lists every port with its config key. |
| `UDM-Port-Scheduler-Guide.pdf` | Step‑by‑step PDF guide covering setup, configuration, cron scheduling, and troubleshooting. |

---

## 🚀 Quick Start

### 1. Download the scripts to your UDM

```bash
curl -sL https://raw.githubusercontent.com/Sparrhawk/ubiquiti-tools/main/port-scheduler.sh -o /root/port-scheduler.sh
curl -sL https://raw.githubusercontent.com/Sparrhawk/ubiquiti-tools/main/find-devices.sh   -o /root/find-devices.sh
chmod +x /root/port-scheduler.sh /root/find-devices.sh
```

### 2. Discover your devices & ports

Edit the credentials at the top of `find-devices.sh`, then run:

```bash
./find-devices.sh
```

You'll see a table like this:

```
Device: Office Switch
  MAC:   aa:bb:cc:dd:ee:ff
  Ports:
  #     Name                 Speed        PoE        Enabled    Config Key
  ------------------------------------------------------------------------------------
  1     Port 1               1000M        auto       True       aa:bb:cc:dd:ee:ff:1
  2     Port 2               1000M        auto       True       aa:bb:cc:dd:ee:ff:2
```

### 3. Configure `port-scheduler.sh`

Open the script and set your controller credentials plus the ports you want to control:

```bash
CONTROLLER="https://localhost"
USERNAME="admin"
PASSWORD="your_password_here"
SITE="default"

PORTS=(
    "aa:bb:cc:dd:ee:ff:1"
    "aa:bb:cc:dd:ee:ff:2"
)
```

### 4. Test manually

```bash
./port-scheduler.sh disable   # Turn ports OFF
./port-scheduler.sh enable    # Turn ports back ON
```

### 5. Automate with cron

Add entries to your UDM's crontab (`crontab -e`):

```cron
# Disable ports at 9pm every night
0 21 * * * /root/port-scheduler.sh disable >> /root/port-scheduler.log 2>&1

# Re-enable ports at 7am every morning
0  7 * * * /root/port-scheduler.sh enable  >> /root/port-scheduler.log 2>&1
```

---

## 📖 Full Guide

For detailed instructions — including SSH access, surviving firmware updates, and troubleshooting — see the **[UDM Port Scheduler Guide (PDF)](UDM-Port-Scheduler-Guide.pdf)**.

---

## ⚙️ Requirements

- Ubiquiti Dream Machine (any model running UniFi OS 3.x+)
- SSH access to the UDM
- A **local** admin account (not a UniFi cloud / SSO account)
- `curl` and `python3` (both pre‑installed on UniFi OS)

---

## 🔒 Security Notes

- Credentials are stored in plain text inside the scripts. Restrict file permissions:
  ```bash
  chmod 700 /root/port-scheduler.sh /root/find-devices.sh
  ```
- Use a dedicated local‑only admin account with a strong password.
- The scripts communicate over `https://localhost` so traffic never leaves the device.

---

## 📝 License

This project is provided as‑is under the [MIT License](https://opensource.org/licenses/MIT). Use at your own risk.

---

## 🤝 Contributing

Pull requests and issues are welcome! If you've adapted this for a different UniFi device or OS version, please share your experience.
