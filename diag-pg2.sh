#!/bin/bash
# Только чтение: ищет корейские/английские названия приложений в базах PostgreSQL и оставшиеся файлы с ними.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
T=$(mktemp -d); trap 'rm -rf $T' EXIT; chmod 755 $T
echo "## базы"; sudo -u postgres psql -Atc "select datname from pg_database where not datistemplate" 2>&1 | head
sudo -u postgres timeout 120 pg_dumpall > $T/all.sql 2>$T/err; echo "  дамп: $(stat -c %s $T/all.sql) байт; ошибки: $(head -c 200 $T/err)"
for s in "제어판" "온라인 문서" "Онлайн-офис" "시스템 관리" "Control Panel"; do
  echo "## в дампе: $s  (совпадений: $(grep -ac -- "$s" $T/all.sql))"
  grep -a -- "$s" $T/all.sql | head -3 | cut -c1-300 | sed 's/^/    /'
done
echo "## схемы/таблицы с desktop|app|icon в имени"
grep -aE '^CREATE TABLE' $T/all.sql | grep -iE 'desk|app|icon|shortcut|launch' | head -15
echo "## файлы с корейским названием на диске"
grep -rlaF "제어판" /var /etc /opt /usr/local /ugreen /volume1/@appstore 2>/dev/null --exclude-dir=node_modules --exclude-dir=www | grep -v diag- | sed 's/^/    /'
