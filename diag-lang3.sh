#!/bin/bash
# Диагностика 3: поиск строки "Italiano" везде, включая бинарники и .gz
OUT="${1:-/tmp/diag-lang3.txt}"
{
echo "== бинарные/любые файлы со строкой Italiano (вне office) =="
grep -rlaF "Italiano" /ugreen /volume1/@appstore --exclude-dir=onlyoffice --exclude-dir=node_modules --exclude-dir=proc 2>/dev/null | head -20
echo
echo "== .gz со строкой Italiano =="
find /ugreen/@appstore /volume1/@appstore -name '*.gz' -not -path '*onlyoffice*' 2>/dev/null | while read -r f; do zcat "$f" 2>/dev/null | grep -qaF "Italiano" && echo "$f"; done | head -10
echo
echo "== www ctlmgr =="
ls /ugreen/@appstore/com.ugreen.ctlmgr/ 2>/dev/null
ls /ugreen/@appstore/com.ugreen.ctlmgr/www 2>/dev/null | head
echo
echo "== API/ключ языков в en-US.json: строки со словом language =="
grep -o '"[A-Za-z_]*[Ll]ang[A-Za-z_]*":"[^"]*"' /ugreen/@appstore/com.ugreen.ctlmgr/www/locale/en-US.json 2>/dev/null | head -20
} > "$OUT" 2>&1
echo "Готово: $OUT"; wc -c "$OUT"
head -c 7000 "$OUT"
