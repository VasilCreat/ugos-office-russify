#!/bin/bash
# Диагностика: какие программы читают ugos.lang и как проверяют язык (ТОЛЬКО ЧТЕНИЕ). Результат: ~/diag-lang-bin.txt
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"; OUT="${H:-/root}/diag-lang-bin.txt"
{
echo "== ПЕРЕЗАГРУЖАЛСЯ ЛИ NAS (аптайм) =="; uptime -s; date
echo
echo "== файлы-программы, где есть строка ugos.lang =="
BINS=$(grep -rlaF "ugos.lang" /ugreen /usr/local /usr/sbin /usr/bin /opt --exclude-dir=www --exclude-dir=onlyoffice --exclude-dir=proc --exclude-dir=node_modules 2>/dev/null | head -10)
echo "$BINS"
for b in $BINS; do
  echo; echo "---- $b"
  strings -n 5 "$b" 2>/dev/null | grep -iE "ugos\.lang|\.language\.ini|languageList|language/user|getLanguage|GetLang|SupportLang|supportedLang|isSupport.*lang|en-US|default.*lang|lang.*default|fallback" | head -60
done
echo
echo "== процессы со словом ugos / desktop / gateway =="
ps -eo pid,etime,cmd | grep -iE "ugos|ugreen" | grep -v grep | head -25
echo
echo "== юниты systemd =="
systemctl list-units --type=service --no-pager 2>/dev/null | grep -iE "ugos|ugreen|desktop|ctlmgr|gateway" | head -25
} > "$OUT" 2>&1
echo "Готово: $OUT"; wc -c "$OUT"; head -c 4000 "$OUT"
