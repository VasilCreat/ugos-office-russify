#!/bin/bash
# Только чтение: запись i18n слота ko-KR в config.json приложений рабочего стола.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
for d in /ugreen/@appstore /volume1/@appstore; do
  for a in filemgr desktop ctrlpanel storage appmgr; do
    f=$d/com.ugreen.$a/config.json
    [ -f "$f" ] || continue
    echo "## $f"
    python3 - "$f" << 'PY'
import json, sys
c = json.load(open(sys.argv[1]))
for e in c.get("i18n", []):
    if e.get("langName") in ("ko-KR", "en-US"):
        print("  ", e.get("langName"), "|", e.get("name"), "|", str(e.get("description"))[:60])
PY
  done
done
echo "## состояние"; ls /volume1/ugos-russify 2>/dev/null
