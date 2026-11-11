#!/bin/bash
# Диагностика: что записалось на диск после смены языка (ТОЛЬКО ЧТЕНИЕ).
# Использование: выбрать язык в системе, нажать "Применить", в течение 10 минут:  sudo bash diag-lang-save.sh
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"; OUT="${H:-/root}/diag-lang-save.txt"
M="${1:-10}"
{
echo "== файлы, изменённые за последние $M мин (без логов и кэшей) =="
find /ugreen /etc /var/lib /var/cache /volume1/@appstore /volume1/@ugreen /home /root /data /opt -xdev -type f -mmin -$M \
  -not -path '*/log/*' -not -path '*/logs/*' -not -name '*.log' -not -path '*/proc/*' -not -path '*node_modules*' -not -path '*/@appstore/*/www/*' \
  -not -path '*/onlyoffice/*' -not -path '/ugos-russify/*' -not -path '/volume1/ugos-russify/*' -not -name '*.journal' -not -path '*/journal/*' \
  -printf '%TY-%Tm-%Td %TH:%TM  %s  %p\n' 2>/dev/null | sort | tail -80
echo
echo "== из них содержат ru-RU / en-US / de-DE / Русск =="
find /ugreen /etc /var/lib /var/cache /volume1/@appstore /volume1/@ugreen /home /root /data /opt -xdev -type f -mmin -$M -size -20M \
  -not -path '*/log/*' -not -name '*.log' -not -path '*node_modules*' -not -path '*/@appstore/*/www/*' -not -path '*/onlyoffice/*' -not -path '*/ugos-russify/*' 2>/dev/null \
  | while read -r f; do
      if grep -qaE 'ru-RU|en-US|de-DE|ja-JP' "$f" 2>/dev/null; then echo "-- $f"; grep -aoE '.{0,80}(ru-RU|en-US|de-DE|ja-JP).{0,80}' "$f" 2>/dev/null | head -3; fi
    done
echo
echo "== sqlite базы (имена) =="
find /ugreen /var/lib /volume1/@appstore /volume1/@ugreen /data -xdev \( -name '*.db' -o -name '*.sqlite*' \) -mmin -$M 2>/dev/null | head -20
} > "$OUT" 2>&1
echo "Готово: $OUT"; wc -c "$OUT"; head -c 5000 "$OUT"
