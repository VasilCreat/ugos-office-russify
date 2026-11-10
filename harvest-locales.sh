#!/bin/bash
# Сбор английских файлов перевода UGOS в один архив (ТОЛЬКО ЧТЕНИЕ).
#
#   curl -fsSL -o harvest-locales.sh https://raw.githubusercontent.com/VasilCreat/ugos-office-russify/main/harvest-locales.sh
#   sudo bash harvest-locales.sh
#
# Берёт en-US.json / en-US.js из приложений и config.json со списком языков.
# Результат: ugos-en-locales.tar.gz в домашней папке пользователя.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi

ROOTS="${ROOTS:-/ugreen/@appstore /volume1/@appstore}"
U="${SUDO_USER:-root}"
H="$(getent passwd "$U" | cut -d: -f6)"
OUT="${OUT:-${H:-/root}/ugos-en-locales.tar.gz}"
LIST="$(mktemp)"

for r in $ROOTS; do
    [ -d "$r" ] || continue
    find "$r" \( -name node_modules -o -name onlyoffice \) -prune -o \
        -type f \( -name 'en-US.json' -o -name 'en-US.js' -o -name 'config.json' \) -print 2>/dev/null
done | while read -r f; do
    case "$f" in
        */config.json) grep -q languageList "$f" 2>/dev/null && echo "$f" ;;
        *) echo "$f" ;;
    esac
done > "$LIST"

echo "Файлов в архиве: $(wc -l < "$LIST")"
tar -czf "$OUT" -T "$LIST" 2>/dev/null
[ -n "$SUDO_USER" ] && chown "$SUDO_USER" "$OUT" 2>/dev/null
ls -la "$OUT"
echo "Размер файлов без сжатия: $(xargs -a "$LIST" -d '\n' du -ch 2>/dev/null | tail -1)"
rm -f "$LIST"
echo "Готово. Ничего не менялось. Пришли мне $OUT"
