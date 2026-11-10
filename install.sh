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
# Можно (и нужно) запускать заново после каждого обновления
# приложения Online Office — скрипт идемпотентен: если что-то
# уже пропатчено, он просто пропустит этот шаг.
# Чтобы это происходило само, см. setup-autorun.sh.
#
# Запуск вручную:        sudo bash install.sh
# Запуск из автозапуска: sudo bash install.sh --auto
# ============================================================
set -e

APP_DIR="/volume1/@appstore/com.ugreen.office"
LOCALE_DIR="$APP_DIR/www/locale"
CONFIG_JSON="$APP_DIR/config.json"
API_JS="$APP_DIR/onlyoffice/documentserver/web-apps/apps/api/documents/api.js"

# --- Режим --auto (для автозапуска, см. setup-autorun.sh) ---
# Скрипт запоминает «отпечаток» файлов Office, которые он правит. Если с
# прошлого запуска отпечаток не изменился, ничего не делает и не перезапускает
# сервис. Если изменился (обновление Office), применяет русификацию и
# запоминает новый отпечаток. Цикла перезапусков быть не может: после одного
# прогона отпечаток записывается, даже если какой-то патч не применился.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="${RUSSIFY_STATE_FILE:-$SCRIPT_DIR/.russify-state}"
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
if [ "$1" = "--auto" ]; then
    [ -d "$APP_DIR" ] || exit 0
    if [ "$(cat "$STATE_FILE" 2>/dev/null || true)" = "$(state_hash)" ]; then
        exit 0
    fi
    echo "[auto] Файлы Office изменились (обновление?) — применяю русификацию"
fi

echo "=== Русификация UGOS Online Office ==="
echo ""

# --- Шаг 1: Создаём/обновляем ru-RU.json ---
echo "[1/7] Создаём файл локализации ru-RU.json..."
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

# --- Шаг 2: Скрываем en-US locale (интерфейс-обёртка) ---
echo "[2/7] Скрываем en-US locale..."
[ -f "$LOCALE_DIR/en-US.json" ] && mv "$LOCALE_DIR/en-US.json" "$LOCALE_DIR/en-US.json.bak"
[ -f "$LOCALE_DIR/en-US.json.gz" ] && mv "$LOCALE_DIR/en-US.json.gz" "$LOCALE_DIR/en-US.json.gz.bak"
echo "  Готово"

# --- Шаг 3: Патч ugos-framework (fallback-язык интерфейса) ---
echo "[3/7] Патч ugos-framework..."
python3 - << 'PYEOF'
import glob, shutil, gzip

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

    # свежий бэкап при каждом запуске (актуален для версии после обновления)
    shutil.copy2(fw_path, fw_path + '.bak')

    if is_gz:
        data = gzip.open(fw_path).read().decode()
    else:
        with open(fw_path, encoding="utf-8") as f:
            data = f.read()

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
echo "[4/7] Добавляем ru-RU в config.json..."
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
echo "[5/7] Патч api.js (язык + региональный формат редактора)..."
python3 - << 'PYEOF'
import gzip, shutil, os

api_path = "/volume1/@appstore/com.ugreen.office/onlyoffice/documentserver/web-apps/apps/api/documents/api.js"

shutil.copy2(api_path, api_path + '.bak')

with open(api_path) as f:
    data = f.read()

target = 'params += "&lang=ru-RU";'

old_original = 'if (config.editorConfig && config.editorConfig.lang)\n            params += "&lang=" + config.editorConfig.lang;'
old_short_ru = 'params += "&lang=ru";'

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
echo "[6/7] Патч редактора таблиц (регион, язык формул и словаря по умолчанию)..."
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
echo "[7/7] Перезапуск office_serv..."
systemctl restart office_serv
sleep 3
if systemctl is-active --quiet office_serv; then
    echo "  Сервис запущен успешно"
else
    echo "  ОШИБКА: сервис не запустился"
    systemctl status office_serv --no-pager
fi

# в автоматическом режиме запоминаем состояние файлов после наших правок
if [ "$1" = "--auto" ]; then
    state_hash > "$STATE_FILE"
fi

echo ""
echo "=== Готово! ==="
echo ""
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
echo "Проверка: создай НОВУЮ таблицу, Файл -> Параметры -> Региональные"
echo "параметры (там должны быть русский язык формул и регион), затем"
echo "введи =СУММ( — должно появиться автодополнение на русском."
