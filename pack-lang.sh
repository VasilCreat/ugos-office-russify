#!/bin/bash
# Упаковка кода выбора языка оболочки UGOS для анализа (ТОЛЬКО ЧТЕНИЕ).
# Результат: lang-pack.tar.gz в домашней папке пользователя.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"
OUT="${H:-/root}/lang-pack.tar.gz"; LIST="$(mktemp)"; R=/ugreen/@appstore
for app in com.ugreen.desktop com.ugreen.ctlmgr com.ugreen.ugos_serv; do
    W="$R/$app/www"; [ -d "$W" ] || continue
    # js-файлы (и оригиналы .ruorig), в которых есть код выбора языка
    find "$W" \( -name node_modules -o -name locale \) -prune -o -type f \( -name '*.js' -o -name '*.js.ruorig' -o -name '*.html' \) -print 2>/dev/null \
      | while read -r f; do
            grep -qaE 'switchLang|languageList|loginLang|ugos:locale|navigator\.languages|uaLang|follwBrowser' "$f" 2>/dev/null && echo "$f"
        done >> "$LIST"
    for c in "$R/$app/config.json"; do [ -f "$c" ] && echo "$c" >> "$LIST"; done
done
echo /ugreen/language/.language.ini >> "$LIST"
# перечень языковых файлов (только имена)
find $R/com.ugreen.desktop/www $R/com.ugreen.ctlmgr/www -path '*locale*' -name '*.json' 2>/dev/null | head -80 > "$H/lang-locale-files.txt"
echo "$H/lang-locale-files.txt" >> "$LIST"
sort -u "$LIST" | grep -v '^$' > "$LIST.u"
tar -czf "$OUT" -T "$LIST.u" 2>/dev/null
[ -n "$SUDO_USER" ] && chown "$SUDO_USER" "$OUT"
echo "Файлов: $(wc -l < "$LIST.u")"; ls -la "$OUT"; sort -u "$LIST" | xargs -r ls -la 2>/dev/null | awk '{print $5, $9}' | sort -rn | head -20
echo "Готово. Ничего не менялось. Пришлите $OUT"
