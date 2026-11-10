#!/bin/bash
# Русификация оболочки UGOS Pro (рабочий стол, Панель управления, приложения UGREEN).
# Авторство и идея: см. README. Скрипт идемпотентный; откат: --revert
#
#   curl -fsSL -o russify-ugos.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/russify-ugos.sh
#   sudo bash russify-ugos.sh            # установить / обновить
#   sudo bash russify-ugos.sh --revert   # вернуть как было
#
# Что делает:
#  1. Берёт готовые переводы ru/<корень>/<приложение>/.../ru-RU.json из репозитория
#     и кладёт их рядом с en-US.json соответствующего приложения.
#  2. В ugos-framework-*.js принудительно выбирает язык ru-RU, но ТОЛЬКО там, где
#     рядом есть ru-RU.json (иначе приложение сломалось бы на 404).
#  3. Обновляет .gz-копии, отключает .br (иначе сервер отдаст старое).
# Строки, которых нет в переводе, показываются по-английски (откат vue-i18n на en-US).

MODE=install
case "$1" in
    --revert) MODE=revert ;;
    "") ;;
    *) echo "Неизвестный параметр: $1 (допустимо: --revert)"; exit 1 ;;
esac
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0 $*"; exit 1; fi

RAW="${RUSSIFY_RAW:-https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main}"
ROOTS="${RUSSIFY_ROOTS:-ugreen=/ugreen/@appstore volume1=/volume1/@appstore}"
STATE_DIR="${RUSSIFY_INSTALL_DIR:-/volume1/ugos-russify}"
MANIFEST="$STATE_DIR/shell-manifest.txt"
mkdir -p "$STATE_DIR"

TMP=""
if [ "$MODE" = install ]; then
    if [ -n "$RU_SRC" ]; then
        SRC="$RU_SRC"
    else
        TMP="$(mktemp -d)"
        echo "Скачиваю переводы..."
        mkdir -p "$TMP/ru"
        if ! curl -fsSL "$RAW/ru/MANIFEST?t=$(date +%s)" -o "$TMP/MANIFEST"; then
            echo "Не удалось скачать список переводов: $RAW/ru/MANIFEST"; rm -rf "$TMP"; exit 1
        fi
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            mkdir -p "$TMP/ru/$(dirname "$f")"
            if ! curl -fsSL "$RAW/ru/$f?t=$(date +%s)" -o "$TMP/ru/$f"; then
                echo "Не удалось скачать $f"; rm -rf "$TMP"; exit 1
            fi
        done < "$TMP/MANIFEST"
        SRC="$TMP/ru"
    fi
    [ -d "$SRC" ] || { echo "Нет каталога переводов: $SRC"; exit 1; }
fi

python3 - "$MODE" "${SRC:-}" "$MANIFEST" "$ROOTS" << 'PY'
import gzip, json, os, re, shutil, sys

mode, src, manifest, roots_s = sys.argv[1:5]
roots = dict(r.split("=", 1) for r in roots_s.split())
SW = re.compile(r'async switchLang\((\w+),(\w+)=(?:!1|false)\)\{')
INJ = ' %s="ru-RU";'   # вставляется сразу после "{"
DONE = re.compile(r'async switchLang\((\w+),(\w+)=!1\)\{ \1="ru-RU";')

def write_gz(path, data):
    with gzip.GzipFile(path + ".gz", "wb", mtime=0) as g:
        g.write(data)

def disable_br(path):
    b = path + ".br"
    if os.path.exists(b):
        os.replace(b, b + ".stale")

def restore_br(path):
    s = path + ".br.stale"
    if os.path.exists(s):
        os.replace(s, path + ".br")

def frameworks():
    for key, base in roots.items():
        if not os.path.isdir(base): continue
        for dp, dns, fns in os.walk(base):
            dns[:] = [d for d in dns if d not in ("node_modules", "onlyoffice", "locale")]
            for fn in fns:
                if fn.startswith("ugos-framework-") and fn.endswith(".js"):
                    yield os.path.join(dp, fn)

if mode == "install":
    installed = []
    old = open(manifest).read().split() if os.path.exists(manifest) else []
    # 1. переводы
    for key, base in roots.items():
        sd = os.path.join(src, key)
        if not os.path.isdir(sd): continue
        for dp, dns, fns in os.walk(sd):
            for fn in fns:
                if fn != "ru-RU.json": continue
                rel = os.path.relpath(os.path.join(dp, fn), sd)
                dst = os.path.join(base, rel)
                if not os.path.isdir(os.path.dirname(dst)):
                    print("пропуск (нет приложения):", rel); continue
                data = open(os.path.join(dp, fn), "rb").read()
                json.loads(data.decode("utf-8"))           # валидность JSON
                cur = open(dst, "rb").read() if os.path.exists(dst) else None
                if cur != data:
                    open(dst, "wb").write(data); write_gz(dst, data)
                    print("перевод:", rel)
                installed.append(dst)
    # 1б. пустые ru-RU.json там, где перевода ещё нет: язык ru-RU выбирается везде
    #     (рабочий стол задаёт язык приложениям), а непереведённые строки берутся из en-US.
    empty = 0
    for key, base in roots.items():
        if not os.path.isdir(base): continue
        for dp, dns, fns in os.walk(base):
            dns[:] = [d for d in dns if d not in ("node_modules", "onlyoffice")]
            if os.path.basename(dp) == "locale" and "en-US.json" in fns and "ru-RU.json" not in fns:
                dst = os.path.join(dp, "ru-RU.json")
                open(dst, "wb").write(b"{}"); write_gz(dst, b"{}")
                installed.append(dst); empty += 1
    if empty: print("пустых заготовок ru-RU.json (строки пока на английском): %d" % empty)
    # 2. patch framework
    patched = 0; skipped = 0
    for f in frameworks():
        page = os.path.dirname(os.path.dirname(f))
        if not os.path.exists(os.path.join(page, "locale", "ru-RU.json")):
            skipped += 1; continue
        s = open(f, encoding="utf-8").read()
        if DONE.search(s):
            continue
        m = SW.search(s)
        if not m:
            print("ВНИМАНИЕ: не найдена switchLang в", f)
            for mm in list(re.finditer(r"switchLang\(", s))[:4]:
                print("     >>", s[max(0, mm.start() - 40):mm.start() + 110].replace("\n", " "))
            continue
        if not os.path.exists(f + ".ruorig"):
            shutil.copy2(f, f + ".ruorig")
        new = s[:m.end()] + INJ % m.group(1) + s[m.end():]
        data = new.encode("utf-8")
        open(f, "wb").write(data); write_gz(f, data); disable_br(f)
        print("патч framework:", f); patched += 1
    # 3. манифест
    with open(manifest, "w") as mf:
        mf.write("\n".join(sorted(set(installed) | {p for p in old if os.path.exists(p)})) + "\n")
    print("Готово: переводов %d, патчей framework %d (пропущено без перевода: %d)" % (len(installed), patched, skipped))
else:
    n = 0
    for f in frameworks():
        o = f + ".ruorig"
        if os.path.exists(o):
            data = open(o, "rb").read()
            open(f, "wb").write(data); write_gz(f, data); restore_br(f)
            os.remove(o); n += 1
            print("откат framework:", f)
    if os.path.exists(manifest):
        for p in open(manifest).read().split():
            for q in (p, p + ".gz"):
                if os.path.exists(q): os.remove(q)
            print("удалён перевод:", p)
        os.remove(manifest)
    print("Откат завершён, восстановлено framework: %d" % n)
PY
RC=$?
[ -n "$TMP" ] && rm -rf "$TMP"
echo
echo "Обнови страницу в браузере с очисткой кеша (Ctrl+F5)."
exit $RC
