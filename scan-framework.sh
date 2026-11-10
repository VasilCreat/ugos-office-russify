#!/bin/bash
# Разведка: как оболочка UGOS выбирает язык интерфейса (ТОЛЬКО ЧТЕНИЕ).
#
#   curl -fsSL -o scan-framework.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/scan-framework.sh
#   sudo bash scan-framework.sh
#
# Результат: scan-framework.log в домашней папке пользователя (пришли его мне).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"
H="$(getent passwd "$U" | cut -d: -f6)"
LOG="${LOG:-${H:-/root}/scan-framework.log}"
APPS="${APPS:-/ugreen/@appstore/com.ugreen.desktop /ugreen/@appstore/com.ugreen.ctlmgr /ugreen/@appstore/com.ugreen.logmgr}"
exec > >(tee "$LOG") 2>&1

echo "=== Выбор языка в системе (бэкенд) ==="
ls /ugreen/@appstore 2>&1 | tr '\n' ' '; echo
for a in $APPS; do echo "--- $a"; ls "$a" 2>&1 | head -30; ls "$a/www" 2>&1 | head -40; done

timeout 120 python3 - $APPS << 'PY'
import os, re, sys
pats = [r'ugos:locale[^"\']{0,40}', r'languageList', r'navigator\.language', r'locale-sync', r'"en-US"', r'zh-CN']
rx = [re.compile(r'.{0,140}(?:' + p + r').{0,140}', re.S) for p in pats]
shown = 0
for app in sys.argv[1:]:
    www = os.path.join(app, "www")
    if not os.path.isdir(www): continue
    for dp, dns, fns in os.walk(www):
        dns[:] = [d for d in dns if d not in ("node_modules", "locale", "fonts", "img", "images")]
        for fn in fns:
            if not fn.endswith((".js", ".html", ".mjs")): continue
            p = os.path.join(dp, fn)
            try: s = open(p, encoding="utf-8", errors="ignore").read()
            except Exception: continue
            hits = []
            for r, name in zip(rx, pats):
                m = r.findall(s)
                if m: hits.append((name, len(m), m[0].replace("\n", " ")))
            if hits and ("locale" in s or "i18n" in s or "lang" in s.lower()):
                print("\n##", p, len(s) // 1024, "КБ")
                for name, n, snip in hits:
                    print("  [%s x%d] %s" % (name, n, snip[:300]))
                shown += 1
                if shown > 45: sys.exit()
PY
echo; echo "Готово. Ничего не менялось. Лог: $LOG"
sleep 0.5
[ -n "$SUDO_USER" ] && chown "$SUDO_USER" "$LOG" 2>/dev/null
