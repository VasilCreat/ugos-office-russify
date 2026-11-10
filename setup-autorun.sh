#!/bin/bash
# ============================================================
# Автозапуск русификации UGOS Online Office
#
# Ставит systemd-таймер, который раз в 30 минут проверяет, не изменились ли
# файлы Online Office (например, после обновления приложения или прошивки),
# и если изменились, заново применяет install.sh. Если ничего не менялось,
# проверка занимает доли секунды и сервис не перезапускается.
#
# Установка:  sudo bash setup-autorun.sh      (рядом должен лежать install.sh)
# Удаление:   sudo bash setup-autorun.sh --remove
# Проверка:   systemctl list-timers ugos-office-russify.timer
# Журнал:     journalctl -u ugos-office-russify.service -n 50
# ============================================================
set -e

NAME="ugos-office-russify"
INSTALL_DIR="/volume1/ugos-russify"
UNIT_DIR="/etc/systemd/system"

if [ "$(id -u)" -ne 0 ]; then
    echo "Запусти с sudo: sudo bash $0"
    exit 1
fi

if [ "$1" = "--remove" ]; then
    systemctl disable --now "$NAME.timer" 2>/dev/null || true
    rm -f "$UNIT_DIR/$NAME.service" "$UNIT_DIR/$NAME.timer"
    systemctl daemon-reload
    echo "Автозапуск удалён. Файлы в $INSTALL_DIR оставлены, русификация в Office не откатывалась."
    exit 0
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SRC_DIR/install.sh" ]; then
    echo "Не найден install.sh рядом с setup-autorun.sh ($SRC_DIR)."
    echo "Положи оба файла в одну папку и запусти снова."
    exit 1
fi

# Копия скрипта на томе с данными: домашняя папка и системные разделы
# могут очищаться при обновлениях, а /volume1 обычно сохраняется.
mkdir -p "$INSTALL_DIR"
cp "$SRC_DIR/install.sh" "$INSTALL_DIR/install.sh"
cp "$SRC_DIR/setup-autorun.sh" "$INSTALL_DIR/setup-autorun.sh" 2>/dev/null || true
chmod 755 "$INSTALL_DIR/install.sh"

cat > "$UNIT_DIR/$NAME.service" << EOF
[Unit]
Description=Russification of UGOS Online Office (re-apply after updates)
After=office_serv.service

[Service]
Type=oneshot
ExecStart=/bin/bash $INSTALL_DIR/install.sh --auto
EOF

cat > "$UNIT_DIR/$NAME.timer" << EOF
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
systemctl enable --now "$NAME.timer"

echo ""
echo "Готово. Автозапуск установлен."
echo "  Скрипт:  $INSTALL_DIR/install.sh"
echo "  Таймер:  systemctl list-timers $NAME.timer"
echo "  Журнал:  journalctl -u $NAME.service -n 50"
echo ""
echo "Первая проверка пройдёт примерно через минуту. Если файлы Office ещё"
echo "не запоминались, она один раз применит русификацию и перезапустит"
echo "office_serv, это нормально."
echo ""
echo "После обновления прошивки проверь, что таймер на месте:"
echo "  systemctl list-timers $NAME.timer"
echo "Если его нет, запусти: sudo bash $INSTALL_DIR/setup-autorun.sh"
