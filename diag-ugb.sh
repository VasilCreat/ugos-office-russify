#!/bin/bash
# Только чтение: что записано в рабочих копиях конфигов (/var/lib/ugb) и когда загружен NAS.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
echo "загрузка NAS: $(uptime -s)"
for f in /var/lib/ugb/com.ugreen.office/config.json /var/lib/ugb/com.ugreen.filemgr/config.json /var/lib/ugb/com.ugreen.ctrlpanel/config.json; do
  [ -e "$f" ] || { echo "нет: $f"; continue; }
  echo "## $f ($(stat -c '%y' "$f" | cut -c1-19)) $([ -L "$f" ] && echo 'СИМВОЛИЧЕСКАЯ ССЫЛКА')"
  python3 - "$f" << 'PY'
import json, sys
for e in json.load(open(sys.argv[1])).get("i18n", []):
    if e.get("langName") == "ko-KR": print("   ko-KR |", e.get("name"))
PY
done
ls -la /var/lib/ugb | head -40
echo "## slot-i18n: $(ls -la /volume1/ugos-russify/slot-i18n.json 2>&1)"
