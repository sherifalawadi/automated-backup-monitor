# automated-backup-monitor
Automated system backup, disk monitoring, and log management script for Ubuntu Linux. Built with pure Bash and cron.
# 🛡️ Automated System Backup & Monitoring Script

> A pure Bash script for Ubuntu that automates backups, monitors disk usage, rotates logs, and sends email alerts — all driven by cron and a single config file.

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?style=flat&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25?style=flat&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat)

---

## 📌 What It Does

| Feature | Description |
|---|---|
| 💾 **Automated Backups** | Compresses folders into `.tar.gz` archives — daily, weekly, monthly |
| 📊 **Disk Monitoring** | Scans every drive every 30 minutes, alerts at 80% usage |
| 📋 **Log Rotation** | Compresses and archives logs when they exceed 1MB |
| 📧 **Email Alerts** | Sends notifications on backup results, disk warnings, log rotation |
| ⚙️ **Single Config** | One file controls everything — no code editing needed |

---

## 🗂️ Project Structure

```
backup_monitor/
├── backup_monitor.sh   ← Main script (all logic lives here)
├── config.conf         ← Your settings — edit this
├── install.sh          ← One-command installer for Ubuntu
└── README.md
```

---

## ⚡ Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/your-username/automated-backup-monitor.git
cd automated-backup-monitor

# 2. Make scripts executable
chmod +x backup_monitor.sh install.sh

# 3. Run the installer (sets up cron + dependencies)
sudo ./install.sh

# 4. Edit your config
sudo nano /opt/backup_monitor/config.conf

# 5. Run your first backup
sudo backup-monitor backup daily
```

---

## ⚙️ Configuration

Everything is controlled from `config.conf`:

```bash
# Folders to back up (comma-separated)
BACKUP_SOURCES="/home/user/Documents,/etc"

# Where backups are saved
BACKUP_DEST="/var/backups/auto_backup"

# How many backups to keep
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

# Alert when disk usage crosses this %
DISK_THRESHOLD=80

# Email notifications
EMAIL_ENABLED=true
EMAIL_RECIPIENT="admin@gmail.com"
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your_email@gmail.com"
SMTP_PASS="your_app_password"
```

---

## 🔧 How It Works

### 💾 Backup Engine
Uses `tar -czf` to compress your folders into timestamped archives:
```bash
tar -czf Documents_20260508_020001.tar.gz /home/user/Documents
```
- `-c` → create archive
- `-z` → compress with gzip (up to 70% smaller)
- `-f` → save to filename

Backups are sorted into 3 layers and old ones are auto-deleted when limits are reached.

---

### 📊 Disk Monitoring
Every 30 minutes, runs:
```bash
df -h --output=source,size,used,avail,pcent,target
```
When any drive crosses the threshold:
```
[WARN] Disk usage 83% on /dev/sda1 — threshold exceeded!
```
An email alert is sent immediately.

---

### 📋 Log Rotation
Every midnight, checks log file sizes with:
```bash
du -k backup_monitor.log
```
If over 1MB → compressed and archived:
```bash
gzip backup_monitor.log → backup_monitor_20260508.log.gz
```
Archives older than 30 days are deleted automatically.

---

## 🕐 Automatic Schedule (Cron)

| Cron Expression | Schedule | Task |
|---|---|---|
| `*/30 * * * *` | Every 30 minutes | Disk usage check |
| `0 2 * * *` | 2:00 AM daily | Daily backup |
| `0 3 * * 0` | 3:00 AM Sunday | Weekly backup |
| `0 4 1 * *` | 4:00 AM on 1st | Monthly backup |
| `0 0 * * *` | Midnight daily | Log rotation |

---

## 💻 Usage

```bash
sudo backup-monitor backup daily     # Run a daily backup
sudo backup-monitor backup weekly    # Run a weekly backup
sudo backup-monitor backup monthly   # Run a monthly backup
sudo backup-monitor disk             # Check disk usage now
sudo backup-monitor rotate-logs      # Rotate logs now
sudo backup-monitor status           # View full dashboard
```

---

## ✅ Test Results

All features tested live on **Ubuntu 24.04 LTS** virtual machine:

| Test | Result |
|---|---|
| Daily Backup | ✅ PASS |
| Weekly Backup | ✅ PASS |
| Monthly Backup | ✅ PASS |
| Disk Monitoring | ✅ PASS |
| Log Rotation | ✅ PASS |
| Status Dashboard | ✅ PASS |
| Cron Auto-Schedule | ✅ PASS |

---

## 🛠️ Built With

`Bash` · `tar` · `gzip` · `df` · `du` · `cron` · `mailx` · `Ubuntu 24.04`

---

## 📄 License

This project is licensed under the MIT License.
