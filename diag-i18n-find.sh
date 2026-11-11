#!/bin/bash
# Только чтение: где на NAS лежит корейское название приложения (откуда рабочий стол берёт подписи).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
STR="온라인 문서"
echo "== искомая строка: $STR"
for d in /ugreen /volume1/@appstore /var/lib /var/local /etc /opt /usr/local /home; do
  [ -d "$d" ] || continue
  grep -rlaF "$STR" "$d" --exclude-dir=node_modules --exclude-dir=proc --exclude-dir=sys 2>/dev/null | head -20 | sed "s#^#  [$d] #"
done
echo "== БД / кэши, названные app/desktop (последние изменения)"
find /ugreen /volume1/@appstore /var/lib /var/local -xdev \( -iname '*.db' -o -iname '*.sqlite*' -o -iname '*cache*' \) \( -ipath '*app*' -o -ipath '*desk*' -o -ipath '*entry*' \) -not -path '*/node_modules/*' -not -path '*/www/*' 2>/dev/null | head -30
echo "== аптайм"; uptime -s
