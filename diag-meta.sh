#!/bin/bash
# Только чтение: формат .upk.meta (метаданные пакетов, откуда рабочий стол может брать названия).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
echo "## все .upk.meta"; ls -la /ugreen/@cache/.*upk.meta /volume1/@cache/.*upk.meta 2>/dev/null | awk '{print $5, $6, $7, $8, $9}' | head -60
F=/ugreen/@cache/.05_amd64_com.ugreen.ctlmgr.upk.meta
echo "## $F"; file "$F"; python3 - "$F" << 'PY'
import sys
d = open(sys.argv[1], "rb").read()
print("  размер:", len(d)); print("  начало:", d[:160])
for s in ("제어판", "Control Panel", "Панель управления", "langName", "ko-KR"):
    i = d.find(s.encode("utf-8")); print("  %-18s %s" % (s, "нет" if i < 0 else "смещение %d: %r" % (i, d[max(0, i-100):i+140].decode("utf-8", "replace"))))
PY
echo "## кто читает: слежение за .upk.meta в логе entry_serv"
grep -a "upk.meta" /var/ugreen/log/entry_serv.slog* 2>/dev/null | tail -3 | cut -c1-250
