#!/bin/bash
# Диагностика: где UGOS берёт список языков (выпадающий список в Панели управления)
OUT="${1:-/tmp/diag-lang.txt}"
{
echo "== config.json с languageList =="
grep -rIl "languageList" /ugreen/@appstore /volume1/@appstore --include=config.json 2>/dev/null | head -20
echo
echo "== файлы со словом Deutsch =="
grep -rIl "Deutsch" /ugreen/@appstore /volume1/@appstore 2>/dev/null | grep -v node_modules | head -20
echo
echo "== контекст Deutsch =="
grep -rIho ".\{150\}Deutsch.\{200\}" /ugreen/@appstore /volume1/@appstore 2>/dev/null | head -3
echo
echo "== контекст languageList в config.json =="
for f in $(grep -rIl "languageList" /ugreen/@appstore /volume1/@appstore --include=config.json 2>/dev/null | head -3); do echo "-- $f"; grep -o '"languageList"[^]]*]' "$f" | head -2; done
} > "$OUT" 2>&1
echo "Готово: $OUT"; wc -c "$OUT"
cat "$OUT" | head -c 6000
