#!/bin/bash
# Диагностика 2: где в Панели управления/рабочем столе названия языков и сохранение языка входа
OUT="${1:-/tmp/diag-lang2.txt}"
R="/ugreen/@appstore"
{
echo "== languageList ctlmgr / desktop / ctlmgr.index =="
for a in ctlmgr ctlmgr.index desktop ugos_serv; do f="$R/com.ugreen.$a/config.json"; echo "-- $f"; grep -o '"languageList"[^]]*]' "$f" 2>/dev/null; done
echo
echo "== файлы (js/json, не office, не de-DE) где рядом Español и Français =="
grep -rIl "Español" $R /volume1/@appstore --include=*.js --include=*.json --include=*.gz 2>/dev/null | grep -v -e onlyoffice -e node_modules | head -20
echo
echo "== контекст Español (js) =="
grep -rIho ".\{200\}Español.\{250\}" $R --include=*.js 2>/dev/null | head -2
echo
echo "== ключи про язык в desktop/ctlmgr en-US.json =="
grep -rIho '"[A-Za-z_.]*":"\(Follow browser language\|Web login language\|My language\)"' $R 2>/dev/null | sort -u | head
echo
echo "== словарь локалей в ctlmgr/desktop www =="
ls $R/com.ugreen.ctlmgr.index/www/locale 2>/dev/null | head -30
echo
echo "== где в js встречается web login / loginLang / follow =="
grep -rIlE "loginLang|login_lang|followBrowser|followSystem" $R --include=*.js 2>/dev/null | head -10
} > "$OUT" 2>&1
echo "Готово: $OUT"; wc -c "$OUT"
head -c 7000 "$OUT"
