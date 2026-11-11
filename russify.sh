#!/bin/bash
# ============================================================
# Русификация UGREEN NAS (UGOS Pro) целиком: оболочка (рабочий стол,
# Панель управления, Файлы, Хранилище и др.) + Online Office.
# Один запуск, один таймер автоприменения после обновлений.
#
# Авторство: Alexander Bikmukhametov (alexbic.net) — исходная идея для Office;
# vasiliskin (GitHub: VasilCreat) — продолжение, оболочка, переводы.
#   https://github.com/VasilCreat/ugos-office-russify
#
#   curl -fsSL -o russify.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/russify.sh
#   sudo bash russify.sh                  # установить / обновить всё + включить автозапуск
#   sudo bash russify.sh --no-autorun     # без таймера
#   sudo bash russify.sh --remove-autorun # убрать таймер, русификацию оставить
#   sudo bash russify.sh --revert         # вернуть всё как было (и убрать таймер)
#
# Таймер раз в 30 минут сверяет «отпечаток» файлов; если прошивка или
# приложение обновились и перезаписали файлы, русификация применяется заново.
# ============================================================
set -u

MODE=install; AUTORUN=1
for a in "$@"; do
    case "$a" in
        --auto) MODE=auto ;;
        --no-autorun) AUTORUN=0 ;;
        --remove-autorun) MODE=remove ;;
        --revert) MODE=revert ;;
        *) echo "Неизвестный параметр: $a (допустимо: --no-autorun, --remove-autorun, --revert)"; exit 1 ;;
    esac
done
[ "$(id -u)" -eq 0 ] || { echo "Запусти с sudo: sudo bash $0 $*"; exit 1; }

RAW="${RUSSIFY_RAW:-https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main}"
export RUSSIFY_RAW="$RAW"
INSTALL_DIR="${RUSSIFY_INSTALL_DIR:-/volume1/ugos-russify}"
UNIT_DIR="${RUSSIFY_UNIT_DIR:-/etc/systemd/system}"
UNIT=ugos-russify
OLD_UNIT=ugos-office-russify          # таймер старого скрипта только для Office
ROOTS_LIST="${RUSSIFY_ROOTS:-ugreen=/ugreen/@appstore volume1=/volume1/@appstore}"
STATE_FILE="$INSTALL_DIR/.russify-all-state"
mkdir -p "$INSTALL_DIR"

drop_old_timer() {
    systemctl disable --now "$OLD_UNIT.timer" 2>/dev/null || true
    rm -f "$UNIT_DIR/$OLD_UNIT.service" "$UNIT_DIR/$OLD_UNIT.timer"
}
drop_timer() {
    systemctl disable --now "$UNIT.timer" 2>/dev/null || true
    rm -f "$UNIT_DIR/$UNIT.service" "$UNIT_DIR/$UNIT.timer"
    systemctl daemon-reload 2>/dev/null || true
}

# Берём подскрипт: рядом с этим файлом, иначе из репозитория.
fetch() {  # fetch <имя>
    local n="$1" here; here="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" 2>/dev/null && pwd)"
    # Файл рядом берём только из клона репозитория (или при RUSSIFY_LOCAL=1): иначе можно подхватить
    # устаревшую копию, оставшуюся в домашней папке от прошлых запусков.
    if [ -f "$here/$n" ] && [ "$here" != "$INSTALL_DIR" ] && { [ -e "$here/.git" ] || [ -n "${RUSSIFY_LOCAL:-}" ]; }; then
        cp "$here/$n" "$INSTALL_DIR/$n"
    elif [ "$MODE" != auto ] || [ ! -s "$INSTALL_DIR/$n" ]; then
        curl -fsSL "$RAW/$n?t=$(date +%s)" -o "$INSTALL_DIR/$n.new" && mv "$INSTALL_DIR/$n.new" "$INSTALL_DIR/$n" \
            || { echo "Не удалось получить $n"; [ -s "$INSTALL_DIR/$n" ] || exit 1; }
    fi
    chmod 755 "$INSTALL_DIR/$n"
}

# Отпечаток файлов оболочки, которые мы правим.
shell_hash() {
    local d
    for r in $ROOTS_LIST; do
        d="${r#*=}"; [ -d "$d" ] || continue
        find "$d" -type f \( -name 'ugos-framework-*.js' -o -name 'en-US.json' -o -name 'ru-RU.json' \) \
            -printf '%p %s %T@\n' 2>/dev/null
    done | sort | sha256sum | cut -d' ' -f1
}

run_shell()  { bash "$INSTALL_DIR/russify-ugos.sh" "$@"; }
run_office() { [ -d /volume1/@appstore/com.ugreen.office ] && bash "$INSTALL_DIR/install.sh" "$@"; }

case "$MODE" in
revert)
    echo "=== Откат русификации UGOS ==="
    drop_timer; drop_old_timer
    fetch russify-ugos.sh; fetch install.sh
    run_shell --revert
    run_office --revert || true
    rm -f "$STATE_FILE"
    echo "Готово. Обнови страницу в браузере (Ctrl+F5)."
    exit 0 ;;
remove)
    drop_timer; drop_old_timer
    echo "Автозапуск удалён. Русификация осталась."
    exit 0 ;;
auto)
    fetch russify-ugos.sh; fetch install.sh
    if [ "$(cat "$STATE_FILE" 2>/dev/null)" != "$(shell_hash)" ]; then
        echo "[auto] Файлы оболочки изменились (обновление?) — применяю русификацию"
        run_shell || true
        shell_hash > "$STATE_FILE"
    fi
    run_office --auto || true      # сам сверяет отпечаток и ничего не делает без изменений
    exit 0 ;;
esac

# --- установка / обновление ---
echo "=== Русификация UGOS Pro целиком ==="
fetch russify-ugos.sh; fetch install.sh
echo; echo "--- Оболочка (рабочий стол, Панель управления, приложения) ---"
run_shell || echo "ВНИМАНИЕ: оболочка завершилась с ошибкой, см. вывод выше"
if [ -d /volume1/@appstore/com.ugreen.office ]; then
    echo; echo "--- Online Office ---"
    run_office --no-autorun || echo "ВНИМАНИЕ: Office завершился с ошибкой, см. вывод выше"
else
    echo; echo "Online Office не установлен — пропускаю."
fi
shell_hash > "$STATE_FILE"

if [ "$AUTORUN" = 1 ]; then
    drop_old_timer
    cp "$0" "$INSTALL_DIR/russify.sh" 2>/dev/null || curl -fsSL "$RAW/russify.sh?t=$(date +%s)" -o "$INSTALL_DIR/russify.sh"
    chmod 755 "$INSTALL_DIR/russify.sh"
    cat > "$UNIT_DIR/$UNIT.service" << UNITEOF
[Unit]
Description=Russification of UGOS Pro (re-apply after updates)
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $INSTALL_DIR/russify.sh --auto
UNITEOF
    cat > "$UNIT_DIR/$UNIT.timer" << UNITEOF
[Unit]
Description=Periodic check of UGOS Pro russification

[Timer]
OnBootSec=3min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
UNITEOF
    systemctl daemon-reload
    systemctl enable --now "$UNIT.timer" >/dev/null 2>&1
    echo; echo "Автозапуск включён: проверка раз в 30 минут (после обновления прошивки русификация вернётся сама)."
    echo "  Таймер: systemctl list-timers $UNIT.timer   Журнал: journalctl -u $UNIT.service -n 50"
fi
echo; echo "=== Готово. Обнови страницу в браузере (Ctrl+F5) ==="
echo "Убрать автозапуск: sudo bash $INSTALL_DIR/russify.sh --remove-autorun   Откат: sudo bash $INSTALL_DIR/russify.sh --revert"
echo; echo "Проект в разработке, гарантий стабильной работы нет. Если что-то сломалось: sudo bash $INSTALL_DIR/russify.sh --revert"
