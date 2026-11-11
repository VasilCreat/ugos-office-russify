#!/bin/bash
# Только чтение: службы UGOS (как перезапускать app_serv / entry_serv) и откуда фронтенд берёт названия.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
echo "## процессы"; ps -eo pid,lstart,cmd | grep -E 'app_serv|entry_serv|taskmgr_serv|gateway' | grep -v grep | cut -c1-170
echo "## юниты systemd"; systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -iE 'ugreen|ugos|appmgr|desktop|gateway|taskmgr' | cut -c1-150
echo "## какие файлы держит app_serv (ugb, config)"
P=$(pgrep -f app_serv | head -1); [ -n "$P" ] && ls -l /proc/$P/fd 2>/dev/null | grep -E 'ugb|config|\.db' | awk '{print $NF}' | head -15
echo "## фронтенд рабочего стола: как берутся названия"
D=/ugreen/@appstore/com.ugreen.desktop/www
grep -rhoaE '.{70}langNameMap.{90}' $D --include='*.js' 2>/dev/null | head -4
grep -rhoaE '.{60}appName.{60}' $D --include='*.js' 2>/dev/null | head -3
