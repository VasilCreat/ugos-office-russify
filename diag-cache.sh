#!/bin/bash
# Только чтение: что лежит в кэше taskMgrServiceCache и @cache (источник подписей рабочего стола).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
for f in /ugreen/.config/taskMgrServiceCache /ugreen/.config/.appstore/@cache; do
  echo "## $f"; ls -la "$f" 2>&1 | head -8
  [ -f "$f" ] && { file "$f" 2>/dev/null; python3 - "$f" << 'PY'
import sys
d = open(sys.argv[1], "rb").read()
print("  размер:", len(d))
for s in ("온라인 문서", "Онлайн-офис", "Online Office", "제어판", "Control Panel", "Панель управления"):
    i = d.find(s.encode("utf-8"))
    print("  %-18s %s" % (s, "нет" if i < 0 else "смещение %d: %r" % (i, d[max(0, i-120):i+160].decode("utf-8", "replace"))))
PY
  }
  [ -d "$f" ] && { ls -la "$f" | head -20; grep -rlaF "온라인 문서" "$f" 2>/dev/null | head; }
done
echo "## кто читает: процессы с открытым файлом"; (command -v lsof >/dev/null && lsof /ugreen/.config/taskMgrServiceCache 2>/dev/null | head -5) || echo "lsof нет"
