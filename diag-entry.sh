#!/bin/bash
# Только чтение: как рабочий стол получает список приложений (адреса API и записи в логе entry_serv).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
D=/ugreen/@appstore/com.ugreen.desktop/www
echo "## адреса API в фронтенде рабочего стола (про приложения/иконки)"
grep -rhoaE '/ugreen/v1/[A-Za-z0-9_/.-]*(app|icon|desk|launch|task)[A-Za-z0-9_/.-]*' $D --include='*.js' 2>/dev/null | sort | uniq -c | sort -rn | head -25
echo "## поля имён рядом с списком приложений"
grep -rhoaE '.{80}(langNameMap|displayName|appName|i18nName|nameMap).{120}' $D --include='*.js' 2>/dev/null | grep -v 'window.name' | head -6
echo "## журнал entry_serv (последние строки про приложения/язык)"
for f in /var/ugreen/log/entry_serv.slog /var/ugreen/log/entry_serv.slog.1; do [ -f $f ] && grep -aiE 'app|lang|meta|cache' $f | tail -8 | cut -c1-260; done
echo "## как entry_serv подключается к Postgres (пароли скрыты)"
sed -E 's/(pass(word)?[^=]*=).*/\1***/I' /etc/default/ugreen-psql 2>/dev/null | head -10
