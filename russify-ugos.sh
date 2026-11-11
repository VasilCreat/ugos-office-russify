#!/bin/bash
# Русификация оболочки UGOS Pro (рабочий стол, Панель управления, приложения UGREEN).
# Авторство и идея: см. README. Скрипт идемпотентный; откат: --revert
#
#   curl -fsSL -o russify-ugos.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/russify-ugos.sh
#   sudo bash russify-ugos.sh            # установить / обновить
#   sudo bash russify-ugos.sh --revert   # вернуть как было
#
# Как это работает (подробно: docs/LANGUAGES.md).
# Служба и шлюз UGOS принимают только свои 11 языков, список зашит в программы, поэтому
# настоящий язык ru-RU добавить нельзя. Мы занимаем слот корейского (ko-KR):
#  1. В /ugreen/language/.language.ini у ko-KR название меняется на «Русский»:
#     так пункт появляется в списке языков, а система сама считает его корейским
#     и без проблем отдаёт его приложениям, шлюзу, Office.
#  2. Готовые переводы ru/<корень>/<приложение>/.../ru-RU.json кладутся как locale/ko-KR.json
#     (оригинал сохраняется рядом как ko-KR.json.ruorig). Где перевода нет, кладётся {}:
#     строки берутся из en-US (откат vue-i18n), а не показываются по-корейски.
#  3. В config.json приложений запись i18n для ko-KR (название и описание приложения)
#     заменяется русской; оригинал сохраняется отдельно.
# Английский (en-US) не трогается. Откат возвращает всё как было.

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
        curl -fsSL "$RAW/ru/apps-i18n.json?t=$(date +%s)" -o "$TMP/ru/apps-i18n.json" \
            || echo "Не удалось скачать apps-i18n.json (названия приложений на рабочем столе останутся английскими)"
        mkdir -p "$TMP/ru/csv"
        for c in ugreen.csv; do
            curl -fsSL "$RAW/ru/csv/$c.json?t=$(date +%s)" -o "$TMP/ru/csv/$c.json" \
                || echo "Не удалось скачать csv/$c.json (системные сообщения останутся на прежнем языке)"
        done
        SRC="$TMP/ru"
    fi
    [ -d "$SRC" ] || { echo "Нет каталога переводов: $SRC"; exit 1; }
fi

python3 - "$MODE" "${SRC:-}" "$MANIFEST" "$ROOTS" << 'PY'
import glob, gzip, json, os, re, shutil, sys

mode, src, manifest, roots_s = sys.argv[1:5]
roots = dict(r.split("=", 1) for r in roots_s.split())
state_dir = os.path.dirname(manifest)
SLOT = "ko-KR"                      # слот языка, который занимает русский
SLOT_JSON = SLOT + ".json"
LANGDIR = os.environ.get("RUSSIFY_LANGDIR", "/ugreen/language")
INI = os.path.join(LANGDIR, ".language.ini")
INI_SIDE = os.path.join(state_dir, "slot-ini.txt")        # исходное название слота в .language.ini
I18N_SIDE = os.path.join(state_dir, "slot-i18n.json")     # исходные записи i18n слота
NAME = "Русский"

def csv_edit(install):
    """Словари сообщений /ugreen/language/*.csv: колонку ko-KR заполняем русским, оригинал храним в state_dir."""
    import csv, io
    n = 0
    cdir = os.path.join(src, "csv") if install else None
    names = sorted(f[:-5] for f in os.listdir(cdir) if f.endswith(".csv.json")) if install and os.path.isdir(cdir) else \
            sorted(f[4:-5] for f in os.listdir(state_dir) if f.startswith("csv-") and f.endswith(".orig")) if not install else []
    for name in names:
        path = os.path.join(LANGDIR, name)
        side = os.path.join(state_dir, "csv-%s.orig" % name)
        if not install:
            if os.path.exists(side) and os.path.exists(path):
                open(path, "wb").write(open(side, "rb").read()); n += 1
            if os.path.exists(side): os.remove(side)
            continue
        if not os.path.exists(path): continue
        tr = json.load(open(os.path.join(cdir, name + ".json"), encoding="utf-8"))
        raw = open(path, "rb").read()
        txt = raw.decode("utf-8")
        rows = list(csv.reader(io.StringIO(txt, newline="")))
        if not rows or SLOT not in rows[0]: continue
        ci = rows[0].index(SLOT)
        ours = any(len(r) > ci and r[0] in tr and r[ci] == tr[r[0]] for r in rows[1:])
        if not ours or not os.path.exists(side):
            open(side, "wb").write(raw)                      # новый оригинал (первый запуск или после обновления)
        for r in rows[1:]:
            if len(r) > ci and r[0] in tr: r[ci] = tr[r[0]]
        out = io.StringIO()
        csv.writer(out, lineterminator="\r\n" if "\r\n" in txt else "\n").writerows(rows)
        if out.getvalue() != txt:
            open(path, "w", encoding="utf-8", newline="").write(out.getvalue()); n += 1
    return n

def write_gz(path, data):
    with gzip.GzipFile(path + ".gz", "wb", mtime=0) as g:
        g.write(data)

def restore_br(path):
    s = path + ".br.stale"
    if os.path.exists(s):
        os.replace(s, path + ".br")

# /var/lib/ugb/<приложение>/config.json: рабочая копия конфигов, откуда службы берут названия приложений
UGB = os.environ.get("RUSSIFY_UGB", "/var/lib/ugb")
META_DIRS = os.environ.get("RUSSIFY_META", "/ugreen/@cache /volume1/@cache").split()

def lang_configs():
    for key, base in roots.items():
        for c in sorted(glob.glob(os.path.join(base, "*", "config.json"))):
            yield c
    for c in sorted(glob.glob(os.path.join(UGB, "*", "config.json"))):
        if not os.path.islink(c): yield c
    # метаданные пакетов (JSON с тем же массивом i18n): рабочий стол берёт названия приложений отсюда
    for d in META_DIRS:
        for c in sorted(glob.glob(os.path.join(d, ".*upk.meta"))):
            if not os.path.islink(c): yield c

def frameworks():
    for key, base in roots.items():
        if not os.path.isdir(base): continue
        for dp, dns, fns in os.walk(base):
            dns[:] = [d for d in dns if d not in ("node_modules", "onlyoffice", "locale")]
            for fn in fns:
                if fn.startswith("ugos-framework-") and fn.endswith(".js"):
                    yield os.path.join(dp, fn)

# ---- блок i18n в config.json (правим текст точечно, формат файла сохраняется) ----
I18N_KEY = re.compile(r'"i18n"\s*:\s*')

def i18n_span(t):
    m = I18N_KEY.search(t)
    if not m: return None
    try:
        arr, end = json.JSONDecoder().raw_decode(t, m.end())
    except ValueError:
        return None
    return (m.end(), end, arr) if isinstance(arr, list) else None

def dump_i18n(arr):
    return json.dumps(arr, ensure_ascii=False, separators=(",", ":"))

# ---- очистка следов прошлых версий (язык ru-RU, подмена switchLang) ----
LANG_RE = re.compile(r'("languageList"\s*:\s*\[)([^\]]*)(\])')

def legacy_cleanup():
    n = 0
    for f in frameworks():                                   # старая подмена switchLang
        o = f + ".ruorig"
        if os.path.exists(o):
            data = open(o, "rb").read()
            open(f, "wb").write(data); write_gz(f, data); restore_br(f)
            os.remove(o); n += 1
    for base in roots.values():                              # пустые заглушки ru-RU.json прошлых версий
        for dp, dns, fns in os.walk(base):
            if "node_modules" in dp or "onlyoffice" in dp: continue
            if "ru-RU.json" in fns:
                p = os.path.join(dp, "ru-RU.json")
                try:
                    if open(p, encoding="utf-8").read().strip() in ("{}", ""):
                        os.remove(p); n += 1
                        if os.path.exists(p + ".gz"): os.remove(p + ".gz")
                except (OSError, ValueError): pass
    k = 0
    for c in lang_configs():                                 # ru-RU в languageList и i18n
        t = open(c, encoding="utf-8").read(); new = t
        m = LANG_RE.search(new)
        if m and '"ru-RU"' in m.group(2):
            items = [x for x in re.findall(r'"[^"]*"', m.group(2)) if x != '"ru-RU"']
            new = new[:m.start(2)] + ",".join(items) + new[m.end(2):]
        sp = i18n_span(new)
        if sp and any(x.get("langName") == "ru-RU" for x in sp[2]):
            a, b, arr = sp
            new = new[:a] + dump_i18n([x for x in arr if x.get("langName") != "ru-RU"]) + new[b:]
        if new != t:
            open(c, "w", encoding="utf-8").write(new); k += 1
    if os.path.exists(INI):                                  # секция [ru-RU] в .language.ini
        t = open(INI, encoding="utf-8").read()
        t2 = re.sub(r"\n?\[ru-RU\]\nname=[^\n]*\nenable=[^\n]*\n?", "\n", t).rstrip("\n") + "\n"
        if t2 != t:
            open(INI, "w", encoding="utf-8").write(t2); k += 1
    if n or k:
        print("убраны следы прошлой версии (подмена языка: %d, списки: %d)" % (n, k))

# ---- манифест: строки "M|путь" (был оригинал, лежит .ruorig) и "C|путь" (файла не было) ----
def read_manifest():
    kinds, legacy = {}, []
    if os.path.exists(manifest):
        for line in open(manifest, encoding="utf-8").read().split("\n"):
            line = line.strip()
            if not line: continue
            if "|" in line and line[0] in "MC" and line[1] == "|":
                kinds[line[2:]] = line[0]
            else:
                legacy.append(line)                          # прежний формат: просто пути ru-RU.json
    return kinds, legacy

def put_locale(dst, data, kinds):
    """Записывает locale/ko-KR.json, сохраняя оригинал (.ruorig); повторный запуск оригинал не затирает."""
    bak = dst + ".ruorig"
    if dst in kinds:
        kind = kinds[dst]                                    # уже наш файл: оригинал был сохранён раньше
    elif os.path.exists(dst):
        if not os.path.exists(bak): shutil.copy2(dst, bak)
        kind = "M"
    else:
        kind = "C"
    cur = open(dst, "rb").read() if os.path.exists(dst) else None
    if cur != data:
        open(dst, "wb").write(data)
    write_gz(dst, data)
    return kind

if mode == "install":
    kinds, legacy = read_manifest()
    legacy_cleanup()
    for p in legacy:                                         # файлы ru-RU.json прошлой версии -> пустые заглушки
        if os.path.exists(p):
            open(p, "wb").write(b"{}"); write_gz(p, b"{}")
    new_kinds = {}
    handled = set()
    # 1. переводы -> locale/ko-KR.json
    n_tr = 0
    for key, base in roots.items():
        sd = os.path.join(src, key)
        if not os.path.isdir(sd): continue
        for dp, dns, fns in os.walk(sd):
            for fn in fns:
                if fn != "ru-RU.json": continue
                rel = os.path.relpath(dp, sd)
                ddir = os.path.join(base, rel)
                if not os.path.isdir(ddir):
                    print("пропуск (нет приложения):", rel); continue
                data = open(os.path.join(dp, fn), "rb").read()
                json.loads(data.decode("utf-8"))
                dst = os.path.join(ddir, SLOT_JSON)
                new_kinds[dst] = put_locale(dst, data, kinds)
                handled.add(ddir); n_tr += 1
    # 1б. где перевода нет: пустой {} в слот (непереведённое берётся из en-US, а не по-корейски)
    n_empty = 0
    for key, base in roots.items():
        if not os.path.isdir(base): continue
        for dp, dns, fns in os.walk(base):
            dns[:] = [d for d in dns if d not in ("node_modules", "onlyoffice")]
            if os.path.basename(dp) == "locale" and "en-US.json" in fns and dp not in handled:
                dst = os.path.join(dp, SLOT_JSON)
                new_kinds[dst] = put_locale(dst, b"{}", kinds); n_empty += 1
    print("переводов: %d, пустых заготовок (строки на английском): %d" % (n_tr, n_empty))
    # 2. название слота в списке языков
    if os.path.exists(INI):
        t = open(INI, encoding="utf-8").read()
        m = re.search(r"(\[%s\]\s*\nname=)([^\n]*)" % SLOT, t)
        if not m:
            print("ВНИМАНИЕ: в .language.ini нет секции [%s], язык в списке не появится" % SLOT)
        elif m.group(2).strip() != NAME:
            if not os.path.exists(INI_SIDE):
                open(INI_SIDE, "w", encoding="utf-8").write(m.group(2))
            open(INI, "w", encoding="utf-8").write(t[:m.start(2)] + NAME + t[m.end(2):])
            print("язык: «%s» -> «%s» в %s" % (m.group(2).strip(), NAME, INI))
    else:
        print("ВНИМАНИЕ: нет файла", INI)
    # 3. названия и описания приложений (i18n) в слот
    tp = os.path.join(src, "apps-i18n.json")
    if os.path.exists(tp):
        tr = json.load(open(tp, encoding="utf-8"))
        side = json.load(open(I18N_SIDE, encoding="utf-8")) if os.path.exists(I18N_SIDE) else {}
        n = 0
        for c in lang_configs():
            t = open(c, encoding="utf-8").read()
            sp = i18n_span(t)
            if not sp: continue
            a, b, arr = sp
            en = next((x for x in arr if x.get("langName") == "en-US"), None)
            if not en or en.get("name") not in tr["apps"]: continue
            r = tr["apps"][en["name"]]
            rec = dict(en); rec["langName"] = SLOT; rec["name"] = r["name"]
            if en.get("description") == r["description_en"]: rec["description"] = r["description"]
            if "tags" in en: rec["tags"] = [tr["tags"].get(x, x) for x in en["tags"]]
            idx = next((i for i, x in enumerate(arr) if x.get("langName") == SLOT), None)
            if c not in side:
                side[c] = arr[idx] if idx is not None else None
            if idx is None: arr.append(rec)
            else: arr[idx] = rec
            new = t[:a] + dump_i18n(arr) + t[b:]
            if new != t:
                open(c, "w", encoding="utf-8").write(new); n += 1
        json.dump(side, open(I18N_SIDE, "w", encoding="utf-8"), ensure_ascii=False)
        print("названия приложений: записей изменено: %d" % n)
    else:
        print("названия приложений: нет apps-i18n.json, пропуск")
    print("словари сообщений (csv): изменено файлов: %d" % csv_edit(True))
    # 4. манифест
    with open(manifest, "w", encoding="utf-8") as mf:
        mf.write("\n".join("%s|%s" % (k, p) for p, k in sorted(new_kinds.items())) + "\n")
    print("Готово. В системе выберите язык «%s»." % NAME)
else:
    kinds, legacy = read_manifest()
    # 1. файлы переводов: вернуть оригиналы
    r_ok = r_stub = 0
    for p, k in sorted(kinds.items()):
        bak = p + ".ruorig"
        if k == "M" and os.path.exists(bak):
            data = open(bak, "rb").read()
            open(p, "wb").write(data); write_gz(p, data)
            os.remove(bak); r_ok += 1
        elif k == "C" and os.path.exists(p):
            # файла не было: оставляем пустой {} (если в браузере запомнен язык, окно не будет пустым)
            open(p, "wb").write(b"{}"); write_gz(p, b"{}"); r_stub += 1
    for p in legacy:
        if os.path.exists(p):
            open(p, "wb").write(b"{}"); write_gz(p, b"{}")
    print("файлы языка: возвращено оригиналов %d, оставлено пустых заглушек %d" % (r_ok, r_stub))
    # 2. название слота в списке языков
    if os.path.exists(INI_SIDE):
        orig = open(INI_SIDE, encoding="utf-8").read()
        if os.path.exists(INI):
            t = open(INI, encoding="utf-8").read()
            m = re.search(r"(\[%s\]\s*\nname=)([^\n]*)" % SLOT, t)
            if m:
                open(INI, "w", encoding="utf-8").write(t[:m.start(2)] + orig + t[m.end(2):])
                print("язык: название слота возвращено: «%s»" % orig.strip())
        os.remove(INI_SIDE)
    # 3. i18n приложений
    if os.path.exists(I18N_SIDE):
        side = json.load(open(I18N_SIDE, encoding="utf-8")); n = 0
        for c, orig in side.items():
            if not os.path.exists(c): continue
            t = open(c, encoding="utf-8").read()
            sp = i18n_span(t)
            if not sp: continue
            a, b, arr = sp
            idx = next((i for i, x in enumerate(arr) if x.get("langName") == SLOT), None)
            if idx is None: continue
            if orig is None: del arr[idx]
            else: arr[idx] = orig
            open(c, "w", encoding="utf-8").write(t[:a] + dump_i18n(arr) + t[b:]); n += 1
        os.remove(I18N_SIDE)
        print("названия приложений: возвращено у %d" % n)
    print("словари сообщений (csv): возвращено файлов: %d" % csv_edit(False))
    # 4. следы прошлых версий
    legacy_cleanup()
    if os.path.exists(manifest): os.remove(manifest)
    print("Откат завершён.")
PY
RC=$?
[ "$MODE" = revert ] && rm -f "$STATE_DIR/force-ru" "$STATE_DIR/noforce"
[ -n "$TMP" ] && rm -rf "$TMP"
echo
echo "Обнови страницу в браузере с очисткой кеша (Ctrl+F5)."
exit $RC
