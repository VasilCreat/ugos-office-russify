#!/bin/bash
# Разведка: где на NAS лежат файлы переводов приложений UGOS.
# ТОЛЬКО ЧИТАЕТ, ничего не меняет и не отправляет.
#
#   curl -fsSL -o scan-locales.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/scan-locales.sh
#   sudo bash scan-locales.sh
#
# Что делает: обходит папки приложений и системные каталоги (но не ваши
# общие папки с данными), ищет каталоги, где лежат файлы вида
# en-US.json, zh-CN.json, de-DE.json и т.п., и показывает для каждого
# список языков, есть ли русский, размер и можно ли туда писать.

if [ "$(id -u)" -ne 0 ]; then
    echo "Запусти с sudo: sudo bash $0"
    exit 1
fi

# Лог: пишем в домашнюю папку пользователя, который вызвал sudo (например /home/vasiliy)
U="${SUDO_USER:-root}"
H="$(getent passwd "$U" | cut -d: -f6)"
LOG="${LOG:-${H:-/root}/scan-locales.log}"
exec > >(tee "$LOG") 2>&1

# корни поиска можно переопределить: ROOTS="/path1:/path2" (для проверки)
ROOTS="${ROOTS:-/volume1/@appstore:/usr/ugreen:/usr/local:/opt:/srv}"

echo "=== Приложения в /volume1/@appstore ==="
ls -1 "${APPSTORE:-/volume1/@appstore}" 2>&1 | head -80

echo
echo "=== Монтирование корней поиска (ro = только чтение) ==="
IFS=':' read -ra RL <<< "$ROOTS"
for r in "${RL[@]}"; do
    [ -d "$r" ] || continue
    if command -v findmnt >/dev/null 2>&1; then
        printf '%s -> ' "$r"; findmnt -no TARGET,FSTYPE,OPTIONS -T "$r" 2>&1 | cut -c1-110
    else
        echo "$r"
    fi
done

echo
echo "=== Каталоги с файлами переводов ==="
timeout 180 python3 - "$ROOTS" << 'PY'
import os, re, sys

roots = [r for r in sys.argv[1].split(":") if os.path.isdir(r)]
# имя файла-перевода: en-US.json, zh_CN.json, de-DE.json.gz, ru.json ...
rx = re.compile(r'^([a-z]{2})[-_]([A-Z]{2})(\.json|\.js|\.yaml|\.yml|\.properties|\.po)?(\.gz|\.br|\.bak)?$')
rx_short = re.compile(r'^(en|zh|ru|de|fr|ja|ko|es|it|pt|nl|tr)\.(json|js|yaml|yml|po)(\.gz)?$')
skip_dirs = {"node_modules", ".git", "proc", "sys"}
found = {}      # каталог -> {язык: [файлы]}
russian = []
MAXDEPTH = 12

for root in roots:
    base_depth = root.rstrip("/").count("/")
    for dp, dns, fns in os.walk(root, followlinks=False):
        if dp.count("/") - base_depth > MAXDEPTH:
            dns[:] = []
            continue
        dns[:] = [d for d in dns if d not in skip_dirs]
        for fn in fns:
            m = rx.match(fn)
            lang = None
            if m:
                lang = m.group(1) + "-" + m.group(2)
            else:
                m2 = rx_short.match(fn)
                if m2:
                    lang = m2.group(1)
            if not lang:
                continue
            found.setdefault(dp, {}).setdefault(lang, []).append(fn)
            if lang.lower().startswith("ru"):
                russian.append(os.path.join(dp, fn))

# настоящие каталоги переводов: минимум 3 разных языка
rows = []
for d, langs in found.items():
    if len(langs) < 3:
        continue
    size = 0
    for fl in langs.values():
        for f in fl:
            try:
                size += os.path.getsize(os.path.join(d, f))
            except OSError:
                pass
    # формат файлов: самый частый суффикс
    exts = {}
    for fl in langs.values():
        for f in fl:
            e = ".".join(f.split(".")[1:]) or "?"
            exts[e] = exts.get(e, 0) + 1
    ext = max(exts, key=exts.get)
    rows.append((d, sorted(langs), size, ext, os.access(d, os.W_OK)))

rows.sort(key=lambda r: r[0])
print(f"найдено каталогов с переводами: {len(rows)}\n")
for d, langs, size, ext, w in rows[:60]:
    has_ru = any(l.lower().startswith("ru") for l in langs)
    print(d)
    print(f"   языков: {len(langs)} ({', '.join(langs)})")
    print(f"   формат: *.{ext}   размер: {size//1024} КБ   запись: {'да' if w else 'нет'}   русский: {'ЕСТЬ' if has_ru else 'нет'}")
if len(rows) > 60:
    print(f"\n... и ещё {len(rows)-60} каталогов (показаны первые 60)")

print("\n=== Все файлы с русским языком ===")
if russian:
    for p in sorted(russian)[:40]:
        print(p)
else:
    print("не найдено")
PY
echo
echo "Готово. Скрипт ничего не менял."
echo "Лог сохранён: $LOG"
sleep 0.5
[ -n "$SUDO_USER" ] && chown "$SUDO_USER" "$LOG" 2>/dev/null
