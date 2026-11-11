#!/bin/bash
# Диагностика: где в программах UGOS зашиты коды языков (ТОЛЬКО ЧТЕНИЕ). Результат: ~/diag-lang-bin2.txt
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"; OUT="${H:-/root}/diag-lang-bin2.txt"
python3 - > "$OUT" 2>&1 << 'PY'
import os, re
files = ["/var/targets/ugos_serv", "/ugreen/@appstore/com.ugreen.gateway_pro/lib/libgateway_core.so",
         "/ugreen/@appstore/com.ugreen.desktop/sbin/entry_serv", "/ugreen/@appstore/com.ugreen.appmgr/sbin/app_serv",
         "/ugreen/@appstore/com.ugreen.filemgr/sbin/filemgr_serv", "/ugreen/@appstore/com.ugreen.taskmgr/sbin/taskmgr_serv"]
def vis(b): return re.sub(rb"[^\x20-\x7e]", b"|", b).decode()
for f in files:
    if not os.path.exists(f): print("##", f, "нет файла"); continue
    d = open(f, "rb").read()
    print("##", f, "размер", len(d))
    for needle in (b"ko-KR", b"tr-TR", b"ru-RU", b"ugos.lang"):
        pos = [m.start() for m in re.finditer(re.escape(needle), d)]
        print("  ", needle.decode(), "вхождений:", len(pos))
        for p in pos[:3]:
            print("      @%d: %s" % (p, vis(d[max(0, p-100):p+160])))
PY
echo "Готово: $OUT"; wc -c "$OUT"
