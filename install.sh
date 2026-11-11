#!/bin/bash
# ============================================================
# Русификация UGREEN NAS Online Office (UGOS Pro)
# + фикс регионального формата (даты/числа/формулы) на ru-RU
#
# Автор оригинального скрипта: Alexander Bikmukhametov | alexbic.net
#   https://github.com/alexbic/ugos-office-russify
# Продолжение и доработка (регион, язык формул и словаря,
# идемпотентность, автозапуск): vasiliskin (GitHub: VasilCreat)
#   https://github.com/VasilCreat/ugos-office-russify
#
# Установка одной командой, в SSH на NAS:
#
#   sudo bash install.sh
#
# или без копирования файла (когда репозиторий публичный):
#
#   curl -fsSL https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/install.sh | sudo bash
#
# Скрипт русифицирует Online Office и сам включает автозапуск: раз в
# 30 минут он проверяет файлы Office и, если приложение обновилось,
# применяет русификацию заново. Повторный запуск безопасен
# (идемпотентно: что уже пропатчено, пропускается).
#
# Параметры (обычно не нужны):
#   --no-autorun      только русифицировать, без автозапуска
#   --remove-autorun  убрать автозапуск (русификация в Office остаётся)
#   --revert          полностью откатить русификацию и убрать автозапуск:
#                     curl -fsSL https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/install.sh | sudo bash -s -- --revert
#   --auto            служебный режим для таймера
# ============================================================
set -e

APP_DIR="/volume1/@appstore/com.ugreen.office"
LOCALE_DIR="$APP_DIR/www/locale"
CONFIG_JSON="$APP_DIR/config.json"
API_JS="$APP_DIR/onlyoffice/documentserver/web-apps/apps/api/documents/api.js"

# Где лежит копия скрипта для автозапуска (на томе с данными, а не в
# домашней папке, которую обновления могут очищать) и откуда её брать,
# если скрипт запущен через curl | bash.
INSTALL_DIR="${RUSSIFY_INSTALL_DIR:-/volume1/ugos-russify}"
UNIT_DIR="${RUSSIFY_UNIT_DIR:-/etc/systemd/system}"
UNIT_NAME="ugos-office-russify"
RAW_URL="https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/install.sh"

MODE="install"
AUTORUN=1
for arg in "$@"; do
    case "$arg" in
        --auto)           MODE="auto" ;;
        --no-autorun)     AUTORUN=0 ;;
        --remove-autorun) MODE="remove" ;;
        --revert)         MODE="revert" ;;
        *) echo "Неизвестный параметр: $arg"; echo "Допустимо: --no-autorun, --remove-autorun, --revert"; exit 1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Нужны права администратора. Запусти так: sudo bash install.sh"
    exit 1
fi

# --- Режим --revert: полный откат ---
# Отменяет каждую нашу правку точной обратной заменой строк (не зависит от
# .bak-копий, которые могли быть перезаписаны), возвращает английский
# перевод, убирает автозапуск (иначе он вернул бы русификацию) и
# перезапускает office_serv.
if [ "$MODE" = "revert" ]; then
    echo "=== Откат русификации UGOS Online Office ==="
    echo ""
    echo "[1/3] Убираем автозапуск..."
    systemctl disable --now "$UNIT_NAME.timer" 2>/dev/null || true
    rm -f "$UNIT_DIR/$UNIT_NAME.service" "$UNIT_DIR/$UNIT_NAME.timer"
    systemctl daemon-reload
    rm -f "${RUSSIFY_STATE_FILE:-$INSTALL_DIR/.russify-state}"
    if [ ! -d "$APP_DIR" ]; then
        echo "Папка Online Office не найдена ($APP_DIR), откатывать нечего."
        exit 0
    fi

    echo "[2/3] Отменяем правки файлов..."
    python3 - << 'PYEOF'
import glob, gzip, json, os

app = "/volume1/@appstore/com.ugreen.office"
ds = app + "/onlyoffice/documentserver/web-apps/apps"
locale = app + "/www/locale"

def rd(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def wr(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)

def regz(p):
    """Пересоздать .gz рядом с файлом, если он там был."""
    if os.path.exists(p + ".gz"):
        with open(p, "rb") as fin, gzip.open(p + ".gz", "wb") as fout:
            fout.write(fin.read())

def undo(path, pairs, label):
    """pairs: (что наши патчи поставили, что было в оригинале)."""
    if not os.path.exists(path):
        print(f"  {label}: файл не найден, пропускаем")
        return
    data = rd(path)
    n = 0
    for new, old in pairs:
        if new in data:
            data = data.replace(new, old)
            n += 1
    if n:
        wr(path, data)
        regz(path)
        # вернуть сжатую .br, которую мы отключали при патче
        if os.path.exists(path + ".br.stale") and not os.path.exists(path + ".br"):
            os.rename(path + ".br.stale", path + ".br")
        print(f"  {label}: откачено правок: {n}")
    else:
        print(f"  {label}: наших правок нет")

# 1. редактор таблиц: app.js и ie/app.js
sse = ds + "/spreadsheeteditor/main/"
sse_pairs = [
    ('this.appOptions.region="ru-ru"',
     'this.appOptions.region="string"==typeof this.editorConfig.region?this.editorConfig.region.toLowerCase():this.editorConfig.region'),
    ('this.appOptions={},this.appOptions.lang="ru-RU"}',
     'this.appOptions={},this.appOptions.lang=t.config.lang}'),
    ('this.appOptions.lang="ru-RU",this.appOptions.location=',
     'this.appOptions.lang=this.editorConfig.lang,this.appOptions.location='),
]
for sub in ("app.js", "ie/app.js"):
    undo(sse + sub, sse_pairs, "редактор таблиц " + sub)

# 2. api.js
api_orig = 'if (config.editorConfig && config.editorConfig.lang)\n            params += "&lang=" + config.editorConfig.lang;'
undo(ds + "/api/documents/api.js",
     [('params += "&lang=ru-RU";', api_orig), ('params += "&lang=ru";', api_orig)],
     "api.js")

# 3. ugos-framework: два патча. «Сообщение родительскому окну» откатывается
#    точной заменой. Патч «fallback» ставил <переменная>="ru-RU" вместо
#    <переменная>="en-US" (на новых сборках он не находится и не применялся).
PARENT_NEW = '"ugos:locale-sync-parent",{detail:{locale:"ru-RU"}}'
PARENT_OLD = '"ugos:locale-sync-parent",{detail:{locale:e.locale}}'

def fw_clean(data):
    n = 0
    if PARENT_NEW in data:
        data = data.replace(PARENT_NEW, PARENT_OLD)
        n += 1
    for var in ("xn", "et", "nt", "tt", "lt", "rt"):
        new, old = f'{var}="ru-RU"', f'{var}="en-US"'
        if data.count(new) == 1 and data.count(old) == 0:
            data = data.replace(new, old)
            n += 1
            break
    return data, n

fws = [f for f in glob.glob(app + "/www/assets/ugos-framework-*.js") if not f.endswith(".bak")]
for f in fws:
    label = "ugos-framework " + os.path.basename(f)
    bak = f + ".bak"
    b = rd(bak) if os.path.exists(bak) else ""
    if PARENT_OLD in b and PARENT_NEW not in b:
        wr(f, b)                       # есть чистая копия — берём её целиком
        regz(f)
        print(f"  {label}: восстановлен из .bak")
    else:
        data, n = fw_clean(rd(f))
        if n:
            wr(f, data)
            regz(f)
            print(f"  {label}: откачено правок: {n}")
        else:
            print(f"  {label}: наших правок нет")
for gz in glob.glob(app + "/www/assets/ugos-framework-*.js.gz"):
    if gz[:-3] in fws:
        continue
    data, n = fw_clean(gzip.open(gz).read().decode())
    if n:
        with gzip.open(gz, "wb") as fo:
            fo.write(data.encode())
        print("  ugos-framework (.gz):", "откачено правок:", n)

# 4. перевод: убрать русский, вернуть английский
for name in ("ru-RU.json", "ru-RU.json.gz"):
    p = os.path.join(locale, name)
    if os.path.exists(p):
        os.remove(p)
        print("  удалён", name)
for name in ("en-US.json", "en-US.json.gz"):
    p, b = os.path.join(locale, name), os.path.join(locale, name + ".bak")
    if os.path.exists(b) and not os.path.exists(p):
        os.rename(b, p)
        print("  возвращён", name)

# 5. config.json: убрать ru-RU из списка языков
cfg = app + "/config.json"
if os.path.exists(cfg):
    c = json.load(open(cfg, encoding="utf-8"))
    if "ru-RU" in c.get("languageList", []):
        c["languageList"] = [x for x in c["languageList"] if x != "ru-RU"]
        with open(cfg, "w", encoding="utf-8") as f:
            json.dump(c, f, indent=2)
        print("  config.json: ru-RU убран из languageList")
PYEOF

    echo "[3/3] Перезапуск office_serv..."
    systemctl restart office_serv
    sleep 3
    if systemctl is-active --quiet office_serv; then
        echo "  Сервис запущен успешно"
    else
        echo "  ОШИБКА: сервис не запустился"
        systemctl status office_serv --no-pager
    fi
    echo ""
    echo "=== Откат выполнен ==="
    echo "Теперь в браузере нажми Ctrl+Shift+R и открой Online Office."
    echo "Вернуть русификацию можно той же командой установки."
    exit 0
fi

if [ "$MODE" = "remove" ]; then
    systemctl disable --now "$UNIT_NAME.timer" 2>/dev/null || true
    rm -f "$UNIT_DIR/$UNIT_NAME.service" "$UNIT_DIR/$UNIT_NAME.timer"
    systemctl daemon-reload
    echo "Автозапуск удалён. Русификация в Office не откатывалась."
    echo "Копия скрипта осталась в $INSTALL_DIR, её можно удалить вручную."
    exit 0
fi

# --- Режим --auto (его вызывает таймер) ---
# Скрипт запоминает «отпечаток» файлов Office, которые он правит. Если с
# прошлого запуска отпечаток не изменился, ничего не делает и не перезапускает
# сервис. Если изменился (обновление Office), применяет русификацию и
# запоминает новый отпечаток. Цикла перезапусков быть не может: после одного
# прогона отпечаток записывается, даже если какой-то патч не применился.
STATE_FILE="${RUSSIFY_STATE_FILE:-$INSTALL_DIR/.russify-state}"
state_hash() {
    local ds="$APP_DIR/onlyoffice/documentserver/web-apps/apps"
    {
        sha256sum "$API_JS" \
                  "$ds/spreadsheeteditor/main/app.js" \
                  "$ds/spreadsheeteditor/main/ie/app.js" \
                  "$APP_DIR"/www/assets/ugos-framework-*.js \
                  "$CONFIG_JSON" 2>/dev/null || true
        ls -1 "$LOCALE_DIR" 2>/dev/null || true
    } | sha256sum | cut -d' ' -f1
}
if [ "$MODE" = "auto" ]; then
    [ -d "$APP_DIR" ] || exit 0
    if [ "$(cat "$STATE_FILE" 2>/dev/null || true)" = "$(state_hash)" ]; then
        exit 0
    fi
    echo "[auto] Файлы Office изменились (обновление?) — применяю русификацию"
fi

if [ ! -d "$APP_DIR" ]; then
    echo "Не найдена папка Online Office: $APP_DIR"
    echo "Сначала установи Online Office из Центра приложений UGOS."
    exit 1
fi

echo "=== Русификация UGOS Online Office ==="
echo ""

# --- Шаг 1: Создаём/обновляем ru-RU.json ---
echo "[1/8] Создаём файл локализации ru-RU.json..."
python3 - << 'PYEOF'
import json, gzip, os

locale_dir = "/volume1/@appstore/com.ugreen.office/www/locale"

ru_locale = {
"files": {
"document": "Документ", "recentOpen": "Недавно открытые",
"recentEdit": "Недавно редактированные", "operate": "Действия",
"openEmpty": "Файл не открыт", "collectEmpty": "Нет документов",
"inputPlaceholder": "Введите", "position": "Расположение",
"fileSize": "Размер", "editTime": "Дата изменения",
"createTime": "Дата создания", "open": "Открыть",
"collect": "В избранное", "cancelCollect": "Убрать из избранного",
"rename": "Переименовать", "download": "Скачать",
"nameExist": "Имя уже существует",
"required": "Имя файла не может быть пустым",
"deleteRecord": "Удалить записи", "deleteFile": "Удалить файл",
"information": "Информация",
"cannotOperate": "Документ не найден или доступ запрещён",
"clearFromList": "Убрать из списка", "complete": "Готово",
"fileNameErr": "Имя файла не может содержать: /\\\"|:*?<>",
"close": "Закрыть",
"editTips": "Online Office не синхронизирует изменения из других приложений в реальном времени.",
"deleteRecordTips": "Удалить выбранные записи?",
"deleteFromNAS": "Удалить исходные файлы с NAS",
"deleteFromNASConfirm": "Удалить этот файл с NAS?",
"openFailTips": "Не удалось открыть. Проверьте права доступа."
},
"layout": {
"recentOpen": "Недавно открытые", "collect": "Избранное",
"createBtn": "Новый документ", "open": "Открыть",
"setting": "Настройки", "document": "Документ",
"xlsx": "Таблица", "ppt": "Презентация",
"formTemplates": "Шаблоны", "fromNas": "С NAS",
"fromLocalDevice": "С локального устройства",
"fromLocalTip": "Открыть файл после загрузки с устройства",
"searchPlaceholder": "Поиск", "loading": "Загрузка...",
"fileSizeLimit": "Файл слишком большой. Ограничение: {size} МБ",
"uploadFileError": "Не удалось загрузить",
"selectDefaultPathPlaceholder": "Выберите",
"defaultSavePathIsInvalid": "Недопустимый путь",
"tips": "Подсказки",
"defaultSavePath": "Путь сохранения по умолчанию",
"pleaseConfigDefaultSavePath": "Сначала настройте путь сохранения",
"operateSuccess": "Операция выполнена успешно",
"selfFolder": "Личная папка", "shareFolder": "Общая папка",
"userFolder": "Папка пользователя",
"exceedLimit": "Превышено максимальное количество: {limit}",
"typeError": "Формат не поддерживается",
"ignoreErrorFile": "Пропущены файлы неподдерживаемых форматов",
"openConfirm": "Открыть документ в браузере",
"doNotShow": "Больше не показывать",
"invalidSkipped": "Недопустимые файлы пропущены",
"selectFile": "Выбрать файл",
"selectPath": "Выбрать расположение",
"modal": {"okText": "ОК"}
},
"setting": {
"delete": "Удалить",
"deleteLoadingTips": "Удаление выполняется, не закрывайте приложение",
"deleteTips": "После удаления шрифтов будет использоваться шрифт по умолчанию",
"exceedLimit": "Превышено максимальное количество пакетов шрифтов: {0}",
"exceedSize": "Ограничение размера пакета шрифтов: {0} МБ",
"fontAccept": "Поддерживается импорт шрифтов: otf, otc, ttc, ttf",
"fontImport": "Импорт шрифта",
"fontListHeadTitle": "Название шрифта ({0})",
"importFail": "Не удалось импортировать",
"importFailDetail": "Не удалось импортировать следующие шрифты:",
"importFinish": "Импорт завершён",
"importFontAgree": "Я согласен с «{0}» и гарантирую наличие прав на использование шрифтов",
"importTips": "Не открывайте документы в процессе импорта шрифтов",
"invalidFile": "Недопустимый файл",
"localUpload": "С компьютера", "nasUpload": "С NAS",
"uploading": "Загрузка",
"uploadingTips": "Импорт выполняется, не закрывайте приложение",
"userAgreement": "Пользовательское соглашение",
"importApiFail": "Превышено время ожидания сети",
"deleteError": "Превышено время ожидания при удалении"
},
"fileSelect": {
"cancel": "Отмена", "createFolder": "Создать папку",
"file": "Файл", "folder": "Папка",
"available": "Доступно", "refresh": "Обновить",
"inputError": "Ошибка ввода",
"fileRootMenu": {
"selfFolder": "Личная папка", "shareFolder": "Общая папка",
"userFolder": "Папки пользователей", "labelFolder": "Метки",
"collectFolder": "Избранное", "deviceFolder": "Устройства",
"isoFolder": "ISO образы", "netFolder": "Сетевые диски",
"safeBox": "Хранилище", "shareItems": "Доступ", "usbFolder": "USB"
},
"fileList": {"folderIsEmpty": "Папка пуста"},
"fileTableHeader": {
"name": "Имя", "size": "Размер", "type": "Тип",
"modifyTime": "Изменён", "createTime": "Создан", "lastVisitTime": "Открыт"
},
"fileTools": {
"sort": "Сортировка", "view": "Вид",
"sortName": "По имени", "sortSize": "По размеру",
"sortType": "По типу", "sortAlterDate": "По дате изменения",
"sortCreateDate": "По дате создания", "lastVisitTime": "По дате открытия",
"fromBigToSmall": "По убыванию", "fromSmallToBig": "По возрастанию",
"viewList": "Список", "viewLargeIcon": "Крупные значки"
},
"folderCreate": {
"title": "Создать папку", "okText": "Создать",
"placeholder": "Введите имя папки",
"fileExist": "Папка уже существует",
"failCreate": "Не удалось создать папку",
"longName": "Слишком длинное имя",
"noFreeSpace": "Недостаточно места",
"fileNameErr": "Недопустимые символы в имени"
},
"layout": {"fileTotal": "Всего: {0}", "selectedCount": "Выбрано: {0}"},
"noStorage": {
"tips": "Нет доступных хранилищ",
"content": "Пожалуйста, подключите хранилище",
"userTips": "Нет доступных папок"
},
"from": {"text": "Из"},
"directoryType": {"recycle": "Корзина"},
"supplement": {
"connectError": "Ошибка подключения",
"connectIsRefused": "Подключение отклонено",
"emptyMounted": "Нет подключённых дисков",
"filenameNotEmpty": "Имя файла не может быть пустым"
},
"folderSettingByAuthority": {
"hideSpecifiedFileTip": "Некоторые файлы скрыты"
}
}
}

os.makedirs(locale_dir, exist_ok=True)
path = os.path.join(locale_dir, "ru-RU.json")
with open(path, 'w') as f:
    json.dump(ru_locale, f, ensure_ascii=False)
with open(path, 'rb') as fin:
    with gzip.open(path + '.gz', 'wb') as fout:
        fout.write(fin.read())
print("  ru-RU.json создан/обновлён")
PYEOF

# --- Шаг 2: Возвращаем en-US locale (если ранние версии скрипта его спрятали) ---
# Фреймворк интерфейса ВСЕГДА загружает en-US как язык по умолчанию. Без этого
# файла окно Online Office остаётся пустым (404 на locale/en-US.json).
echo "[2/8] Проверяем en-US locale..."
for n in en-US.json en-US.json.gz; do
    if [ ! -f "$LOCALE_DIR/$n" ] && [ -f "$LOCALE_DIR/$n.bak" ]; then
        mv "$LOCALE_DIR/$n.bak" "$LOCALE_DIR/$n" && echo "  возвращён $n"
    fi
done
echo "  Готово"

# --- Шаг 3: Патч ugos-framework (fallback-язык интерфейса) ---
echo "[3/8] Патч ugos-framework..."
python3 - << 'PYEOF'
import glob, shutil, gzip, os

app_dir = "/volume1/@appstore/com.ugreen.office/www/assets"

# файл может называться по-разному в зависимости от сборки (хэш меняется
# при каждом обновлении), и может быть как обычным .js, так и .js.gz
candidates = glob.glob(f"{app_dir}/ugos-framework-*.js") + glob.glob(f"{app_dir}/ugos-framework-*.js.gz")
candidates = [f for f in candidates if not f.endswith(('.bak', '.bak.gz'))]

if not candidates:
    print("  ОШИБКА: ugos-framework не найден!")
else:
    fw_path = candidates[0]
    is_gz = fw_path.endswith(".gz")
    print(f"  Файл: {fw_path}")

    if is_gz:
        data = gzip.open(fw_path).read().decode()
    else:
        with open(fw_path, encoding="utf-8") as f:
            data = f.read()

    # Резервная копия: только пока файл «чистый» (в нём ещё есть исходный
    # шаблон) или копии ещё нет. Иначе повторный запуск затёр бы оригинал
    # уже пропатченным файлом, и откатиться было бы нельзя.
    pristine = '"ugos:locale-sync-parent",{detail:{locale:e.locale}}' in data
    if pristine or not os.path.exists(fw_path + '.bak'):
        shutil.copy2(fw_path, fw_path + '.bak')

    patched_any = False
    for var in ['xn', 'et', 'nt', 'tt', 'lt', 'rt']:
        old = f'{var}="en-US"'
        if data.count(old) == 1:
            data = data.replace(old, f'{var}="ru-RU"', 1)
            print(f"  Патч 1 (fallback): {old} -> {var}=\"ru-RU\"")
            patched_any = True
            break
    if not patched_any:
        if '="ru-RU"' in data:
            print("  Патч 1: похоже, уже применён ранее — пропускаем")
        else:
            print("  ВНИМАНИЕ: fallback-переменная не найдена (возможно, изменилась структура кода)")

    old2 = '"ugos:locale-sync-parent",{detail:{locale:e.locale}}'
    new2 = '"ugos:locale-sync-parent",{detail:{locale:"ru-RU"}}'
    if old2 in data:
        data = data.replace(old2, new2, 1)
        print("  Патч 2 (ready): locale:e.locale -> locale:\"ru-RU\"")
    elif new2 in data:
        print("  Патч 2: уже применён ранее — пропускаем")
    else:
        print("  ВНИМАНИЕ: ready() паттерн не найден, пропускаем")

    if is_gz:
        with gzip.open(fw_path, 'wb') as f:
            f.write(data.encode())
    else:
        with open(fw_path, 'w', encoding="utf-8") as f:
            f.write(data)
        # если рядом лежит .gz-версия того же файла — обновим и её тоже
        gz_sibling = fw_path + ".gz"
        import os
        if os.path.exists(gz_sibling):
            with gzip.open(gz_sibling, 'wb') as f:
                f.write(data.encode())

    print("  ugos-framework пропатчен")
PYEOF

# --- Шаг 4: Добавляем ru-RU в config.json Office ---
echo "[4/8] Добавляем ru-RU в config.json..."
python3 - << 'PYEOF'
import json
path = "/volume1/@appstore/com.ugreen.office/config.json"
with open(path) as f:
    c = json.load(f)
if "ru-RU" not in c.get("languageList", []):
    c.setdefault("languageList", []).append("ru-RU")
    with open(path, 'w') as f:
        json.dump(c, f, indent=2)
    print("  ru-RU добавлен в languageList")
else:
    print("  ru-RU уже в списке")
PYEOF

# --- Шаг 5: Патч api.js — язык интерфейса И региональный формат редактора ---
# ВАЖНО: используем полный код ru-RU (не короткий "ru"), иначе OnlyOffice
# не сможет вывести из него региональный формат (даты/числа/язык формул)
# и молча откатится на en-US — это и была основная причина проблемы.
echo "[5/8] Патч api.js (язык + региональный формат редактора)..."
python3 - << 'PYEOF'
import gzip, shutil, os

api_path = "/volume1/@appstore/com.ugreen.office/onlyoffice/documentserver/web-apps/apps/api/documents/api.js"

with open(api_path) as f:
    data = f.read()

target = 'params += "&lang=ru-RU";'

old_original = 'if (config.editorConfig && config.editorConfig.lang)\n            params += "&lang=" + config.editorConfig.lang;'
old_short_ru = 'params += "&lang=ru";'

# Резервная копия: только пока файл «чистый» или копии ещё нет (повторный
# запуск не должен затирать оригинал уже пропатченным файлом).
if old_original in data or not os.path.exists(api_path + '.bak'):
    shutil.copy2(api_path, api_path + '.bak')

if target in data:
    print("  Уже пропатчено (lang=ru-RU) — пропускаем")
elif old_short_ru in data:
    data = data.replace(old_short_ru, target)
    with open(api_path, 'w') as f:
        f.write(data)
    print("  Обновлено: lang=ru -> lang=ru-RU")
elif old_original in data:
    data = data.replace(old_original, target)
    with open(api_path, 'w') as f:
        f.write(data)
    print("  api.js пропатчен: lang=ru-RU")
else:
    print("  ВНИМАНИЕ: ни один из ожидаемых паттернов не найден.")
    print("  Возможно, структура api.js изменилась после обновления OnlyOffice.")
    print("  Патч НЕ применён — нужна ручная проверка файла:")
    print(f"  {api_path}")

with open(api_path, 'rb') as fin:
    with gzip.open(api_path + '.gz', 'wb') as fout:
        fout.write(fin.read())
PYEOF

# --- Шаг 6: Патч редактора таблиц — регион и язык формул по умолчанию ---
# Редактор берёт регион из editorConfig.region, а если его нет — из
# editorConfig.lang, который присылает сервер (office_serv) и который у UGOS
# английский. Поэтому одного lang=ru-RU в адресе мало: интерфейс станет
# русским, а регион и язык формул останутся en. Здесь задаём им значения
# по умолчанию. Если пользователь сам выбрал регион/язык формул в настройках
# редактора, его выбор сохраняется (он хранится в браузере и имеет приоритет).
echo "[6/8] Патч редактора таблиц (регион, язык формул и словаря по умолчанию)..."
python3 - << 'PYEOF'
import gzip, os, shutil

base = "/volume1/@appstore/com.ugreen.office/onlyoffice/documentserver/web-apps/apps/spreadsheeteditor/main/"
targets = [base + "app.js", base + "ie/app.js"]

# (описание, что ищем, на что меняем)
PATCHES = [
    ("регион по умолчанию",
     'this.appOptions.region="string"==typeof this.editorConfig.region?this.editorConfig.region.toLowerCase():this.editorConfig.region',
     'this.appOptions.region="ru-ru"'),
    ("язык формул по умолчанию",
     'this.appOptions={},this.appOptions.lang=t.config.lang}',
     'this.appOptions={},this.appOptions.lang="ru-RU"}'),
    # appOptions.lang (он же mode.lang) использует диалог настроек и панель
    # проверки орфографии, чтобы выбрать язык словаря по умолчанию
    ("язык словаря по умолчанию",
     'this.appOptions.lang=this.editorConfig.lang,this.appOptions.location=',
     'this.appOptions.lang="ru-RU",this.appOptions.location='),
]

for path in targets:
    short = os.path.relpath(path, base)
    if not os.path.exists(path):
        print(f"  {short}: файл не найден — пропускаем")
        continue
    with open(path, encoding="utf-8") as f:
        data = f.read()

    new_data = data
    changed = False
    for name, old, new in PATCHES:
        if new in new_data and old not in new_data:
            print(f"  {short}: {name} — уже применено, пропускаем")
        elif old in new_data:
            cnt = new_data.count(old)
            new_data = new_data.replace(old, new)
            changed = True
            print(f"  {short}: {name} — патч применён (замен: {cnt})")
        else:
            print(f"  {short}: ВНИМАНИЕ: {name} — шаблон не найден, патч НЕ применён")
            print("    (структура app.js могла измениться после обновления OnlyOffice)")

    if changed:
        # Бэкап оригинала (.ruorig): обновляем его, только если файл чистый
        # (свежий после обновления OnlyOffice). Если наши патчи в файле уже
        # есть, старый бэкап с настоящим оригиналом не трогаем.
        was_patched = any(new in data for _, _, new in PATCHES)
        if not was_patched or not os.path.exists(path + ".ruorig"):
            shutil.copy2(path, path + ".ruorig")
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_data)
        # сжатые копии, если они есть, иначе nginx отдаст старый файл
        if os.path.exists(path + ".gz"):
            with open(path, "rb") as fin, gzip.open(path + ".gz", "wb") as fout:
                fout.write(fin.read())
            print(f"  {short}: .gz пересоздан")
        if os.path.exists(path + ".br"):
            os.rename(path + ".br", path + ".br.stale")
            print(f"  {short}: устаревший .br отключён (.br.stale)")
PYEOF

# --- Шаг 7: Перезапуск сервиса ---
echo "[7/8] Перезапуск office_serv..."
systemctl restart office_serv
sleep 3
if systemctl is-active --quiet office_serv; then
    echo "  Сервис запущен успешно"
else
    echo "  ОШИБКА: сервис не запустился"
    systemctl status office_serv --no-pager
fi

# --- Шаг 8: Автозапуск после обновлений (только при ручном запуске) ---
AUTORUN_OK=0
if [ "$MODE" = "install" ] && [ "$AUTORUN" = "1" ]; then
    echo "[8/8] Включаем автозапуск после обновлений..."
    mkdir -p "$INSTALL_DIR"
    SELF="$INSTALL_DIR/install.sh"
    # Берём копию скрипта: из файла, если запущены из файла, иначе (curl | bash)
    # скачиваем заново.
    FROM_FILE=0
    case "$0" in
        bash|sh|-bash|-sh|*/bash|*/sh) ;;
        *) [ -f "$0" ] && FROM_FILE=1 ;;
    esac
    if [ "$FROM_FILE" = "1" ]; then
        if [ "$(readlink -f "$0")" != "$(readlink -f "$SELF" 2>/dev/null || echo "$SELF")" ]; then
            cp "$0" "$SELF"
        fi
    else
        curl -fsSL "$RAW_URL" -o "$SELF" 2>/dev/null || rm -f "$SELF"
    fi
    if [ -s "$SELF" ]; then
        chmod 755 "$SELF"
        # Запоминаем состояние файлов ДО включения таймера: systemd запускает
        # таймер сразу (загрузка уже прошла), и без этого он начинал бы второй
        # полный прогон, пока этот ещё не записал отпечаток.
        state_hash > "$STATE_FILE"
        cat > "$UNIT_DIR/$UNIT_NAME.service" << EOF
[Unit]
Description=Russification of UGOS Online Office (re-apply after updates)
After=office_serv.service

[Service]
Type=oneshot
ExecStart=/bin/bash $SELF --auto
EOF
        cat > "$UNIT_DIR/$UNIT_NAME.timer" << EOF
[Unit]
Description=Periodic check of UGOS Online Office russification

[Timer]
OnBootSec=3min
OnActiveSec=1min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
EOF
        systemctl daemon-reload
        systemctl enable --now "$UNIT_NAME.timer"
        AUTORUN_OK=1
        echo "  Автозапуск включён (проверка раз в 30 минут)"
    else
        echo "  ВНИМАНИЕ: не удалось сохранить копию скрипта, автозапуск не включён."
        echo "  Сохрани install.sh в файл и запусти: sudo bash install.sh"
    fi
fi

# запоминаем состояние файлов после наших правок, чтобы таймер не делал
# лишний прогон и перезапуск сервиса
if [ "$MODE" = "auto" ] || { [ "$MODE" = "install" ] && [ "$AUTORUN" = "0" ]; }; then
    mkdir -p "$(dirname "$STATE_FILE")"
    state_hash > "$STATE_FILE"
fi

echo ""
echo "=== Готово! ==="
echo ""
if [ "$AUTORUN_OK" = "1" ]; then
    echo "Автозапуск: после обновления Office русификация вернётся сама."
    echo "  Проверить таймер:  systemctl list-timers $UNIT_NAME.timer"
    echo "  Журнал:            journalctl -u $UNIT_NAME.service -n 50"
    echo "  Убрать автозапуск: sudo bash $INSTALL_DIR/install.sh --remove-autorun"
    echo "  После обновления ПРОШИВКИ проверь, что таймер на месте; если нет —"
    echo "  запусти установку ещё раз."
    echo ""
fi
echo "Действия на клиенте:"
echo "  Браузер (Windows/Mac/Linux): нажми Ctrl+Shift+R на странице документа."
echo "    Если не помогло: F12 -> Application -> Storage -> Clear site data"
echo "    для адреса NAS, затем открой документ заново."
echo "  Приложение UGREEN NAS на Mac:"
echo '    1. Закрыть приложение'
echo '    2. rm -rf "$HOME/Library/UGREEN_Nas_Pro/.cache/office/"'
echo '    3. rm -rf "$HOME/Library/Application Support/com.ugreen.desktop/Cache/Cache_Data/"'
echo '    4. Открыть приложение'
echo ""
echo "Проект в разработке, гарантий стабильной работы нет. Если что-то сломалось: sudo bash install.sh --revert"
echo ""
echo "Проверка: создай НОВУЮ таблицу, Файл -> Параметры -> Региональные"
echo "параметры (там должны быть русский язык формул и регион), затем"
echo "введи =СУММ( — должно появиться автодополнение на русском."
