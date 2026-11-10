#!/bin/bash
# Диагностика русификации Online Office. Только читает, ничего не меняет.
#
#   curl -fsSL https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/diag.sh | sudo bash
#
APP="${APP:-/volume1/@appstore/com.ugreen.office}"
L="$APP/www/locale"

echo "=== office_serv ==="
systemctl is-active office_serv 2>&1

echo; echo "=== файлы перевода ($L) ==="
ls -la "$L" 2>&1

echo; echo "=== ugos-framework ==="
ls -la "$APP"/www/assets/ugos-framework-* 2>&1
for f in "$APP"/www/assets/ugos-framework-*.js; do
    [ -f "$f" ] || continue
    if [ -f "$f.gz" ]; then
        if [ "$(gzip -dc "$f.gz" | sha256sum | cut -d' ' -f1)" = "$(sha256sum < "$f" | cut -d' ' -f1)" ]; then
            echo "OK: $(basename "$f") и его .gz одинаковые"
        else
            echo "ВНИМАНИЕ: $(basename "$f") и его .gz РАЗНЫЕ (может отдаваться старая версия)"
        fi
    fi
done

echo; echo "=== сравнение ключей перевода (русский и английский оригинал) ==="
python3 - "$L" << 'PY'
import json, os, gzip, sys
d = sys.argv[1]

def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def keys(o, p=""):
    s = set()
    for k, v in o.items():
        q = p + "." + k if p else k
        if isinstance(v, dict):
            s |= keys(v, q)
        else:
            s.add(q)
    return s

en_path = None
for name in ("en-US.json.bak", "en-US.json"):
    if os.path.exists(os.path.join(d, name)):
        en_path = os.path.join(d, name)
        break
ru_path = os.path.join(d, "ru-RU.json")

if not en_path:
    print("английский оригинал не найден (нет en-US.json и en-US.json.bak)")
elif not os.path.exists(ru_path):
    print("нет ru-RU.json")
else:
    try:
        en, ru = keys(load(en_path)), keys(load(ru_path))
    except Exception as e:
        print("ОШИБКА чтения JSON:", e)
        sys.exit()
    print("английский оригинал:", os.path.basename(en_path), "- ключей:", len(en))
    print("ru-RU.json:", "ключей:", len(ru))
    miss = sorted(en - ru)
    print("НЕТ в русском:", len(miss))
    for k in miss[:40]:
        print("   ", k)
    print("лишних в русском:", len(ru - en))
    gz = ru_path + ".gz"
    if os.path.exists(gz):
        same = gzip.open(gz).read() == open(ru_path, "rb").read()
        print("ru-RU.json.gz совпадает с ru-RU.json:", same)
    for other in ("de-DE.json", "fr-FR.json"):
        p = os.path.join(d, other)
        if os.path.exists(p):
            try:
                print(other, "- ключей:", len(keys(load(p))))
            except Exception as e:
                print(other, "ошибка:", e)
PY

echo; echo "=== таймер автозапуска ==="
systemctl list-timers ugos-office-russify.timer --no-pager 2>&1 | head -4
echo; echo "=== журнал таймера (последние строки) ==="
journalctl -u ugos-office-russify.service -n 12 --no-pager 2>&1
echo; echo "=== журнал office_serv (последние строки) ==="
journalctl -u office_serv -n 12 --no-pager 2>&1
