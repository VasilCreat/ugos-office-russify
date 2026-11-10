#!/bin/bash
# Упаковка файлов фронтенда оболочки UGOS для анализа (ТОЛЬКО ЧТЕНИЕ).
#
#   curl -fsSL -o pack-framework.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/pack-framework.sh
#   sudo bash pack-framework.sh
#
# Результат: fw.tar.gz в домашней папке пользователя.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"
H="$(getent passwd "$U" | cut -d: -f6)"
OUT="${OUT:-${H:-/root}/fw.tar.gz}"
W="${W:-/ugreen/@appstore/com.ugreen.desktop/www}"
[ -d "$W" ] || { echo "Нет папки $W"; exit 1; }
cd "$W" || exit 1
FILES="index.html"
for f in static/ugos-framework-*.js static/desktop-*.js static/main-*.js static/index-*.js; do
    [ -f "$f" ] || continue
    # index-C3SKsg0I (6 МБ) пропускаем: слишком большой
    [ "$(stat -c %s "$f")" -gt 1500000 ] && continue
    FILES="$FILES $f"
done
tar -czf "$OUT" $FILES
[ -n "$SUDO_USER" ] && chown "$SUDO_USER" "$OUT"
ls -la "$OUT"
tar -tzf "$OUT"
echo "Готово. Ничего не менялось. Пришли мне $OUT"
