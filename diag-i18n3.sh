#!/bin/bash
# Диагностика 3: откуда рабочий стол берёт подписи иконок (только чтение). Результат: ~/diag-i18n3.txt
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"; OUT="${H:-/root}/diag-i18n3.txt"
{
echo "== ru-RU в i18n у filemgr (должно быть 1, если установка b4416cf применена) =="
grep -o '"langName":"ru-RU"' /ugreen/@appstore/com.ugreen.filemgr/config.json | wc -l
grep -o '{"name":"Файлы"[^}]*}' /ugreen/@appstore/com.ugreen.filemgr/config.json | head -c 300; echo
echo
echo "== где встречается Papierkorb (все файлы, включая бинарники) =="
grep -rlaF "Papierkorb" /ugreen /volume1/@appstore --exclude-dir=onlyoffice --exclude-dir=node_modules --exclude-dir=proc 2>/dev/null | head -15
echo
echo "== шапки csv в /ugreen/language =="
for f in /ugreen/language/ugreen.csv /ugreen/language/msgcli.csv /ugreen/language/ugtask.csv; do echo "-- $f"; head -c 400 "$f"; echo; done
echo
echo "== строки csv с Recycle Bin / Papierkorb =="
grep -rhaF -e "Recycle Bin" -e "Papierkorb" /ugreen/language/*.csv 2>/dev/null | head -5 | cut -c1-400
echo
echo "== строки csv с Task Manager =="
grep -rhaF "Task Manager" /ugreen/language/*.csv 2>/dev/null | head -3 | cut -c1-400
} > "$OUT" 2>&1
echo "Готово: $OUT"; wc -c "$OUT"
