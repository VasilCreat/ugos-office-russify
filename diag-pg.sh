#!/bin/bash
# Только чтение: где живёт PostgreSQL UGOS и лежат ли в нём названия приложений.
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
echo "## процессы postgres"; ps -eo pid,user,cmd | grep -E '[p]ostgres|[p]sql' | cut -c1-200 | head -8
DD=$(ps -eo cmd | grep -oE '(-D|--pgdata=?) *[^ ]+' | head -1 | awk '{print $NF}' | sed 's/--pgdata=//')
echo "## каталог данных: ${DD:-не найден}"
echo "## бинарники"; for b in psql pg_ctl; do command -v $b || find / -xdev -name $b -type f 2>/dev/null | head -2; done
echo "## unit ugreen-psql"; systemctl cat ugreen-psql.service 2>/dev/null | grep -E 'Exec|User|Environment|Working' | head -8
echo "## где лежат корейские названия приложений (по всей системе, кроме пользовательских данных)"
for s in "제어판" "온라인 문서"; do
  echo "  строка: $s"
  grep -rlaF "$s" /var /etc /opt /usr/local /ugreen /volume1/@appstore /volume1/@* 2>/dev/null --exclude-dir=node_modules --exclude-dir=www | grep -v diag- | head -8 | sed 's/^/    /'
done
