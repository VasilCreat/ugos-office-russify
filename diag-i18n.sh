#!/bin/bash
# Диагностика: блоки i18n в config.json приложений (только чтение). Результат: ~/diag-i18n.txt
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"; OUT="${H:-/root}/diag-i18n.txt"
python3 - /ugreen/@appstore /volume1/@appstore > "$OUT" << 'PY'
import glob, json, os, sys
for base in sys.argv[1:]:
    for c in sorted(glob.glob(os.path.join(base, "*", "config.json"))):
        try: d = json.load(open(c, encoding="utf-8"))
        except Exception as e: print("##", c, "ОШИБКА", e); continue
        print("##", c)
        print("keys:", list(d.keys()))
        print("languageList:", d.get("languageList"))
        i = d.get("i18n")
        if i is None: print("i18n: нет"); continue
        s = json.dumps(i, ensure_ascii=False)
        print("i18n-type:", type(i).__name__, "len:", len(s))
        print(s[:1500])
PY
echo "Готово: $OUT"; wc -c "$OUT"; head -c 3000 "$OUT"
