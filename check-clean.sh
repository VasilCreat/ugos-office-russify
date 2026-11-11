#!/bin/bash
# Проверка: остались ли на NAS следы русификации (ТОЛЬКО ЧТЕНИЕ, ничего не меняет).
#   sudo bash check-clean.sh
# После `russify.sh --revert` (и перезагрузки) всё должно быть «чисто», кроме пустых
# заглушек ru-RU.json — они безвредны (см. README).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
R1=/ugreen/@appstore; R2=/volume1/@appstore
OFF=$R2/com.ugreen.office; ODS=$OFF/onlyoffice/documentserver/web-apps/apps
BAD=0
say() { echo "  $1: $2"; }
flag() { say "$1" "$2"; [ "$3" = bad ] && BAD=$((BAD+1)); }

echo "=== Список языков системы ==="
if grep -q '^\[ru-RU\]' /ugreen/language/.language.ini 2>/dev/null; then flag ".language.ini: секция [ru-RU]" "ЕСТЬ (наша)" bad; else say ".language.ini: секция [ru-RU]" "нет"; fi
N=$(grep -l '"languageList"[^]]*"ru-RU"' $R1/*/config.json $R2/*/config.json 2>/dev/null | wc -l)
[ "$N" -gt 0 ] && flag "config.json с ru-RU в languageList" "$N" bad || say "config.json с ru-RU в languageList" "0"
N=$(grep -l '"langName":"ru-RU"' $R1/*/config.json $R2/*/config.json 2>/dev/null | wc -l)
[ "$N" -gt 0 ] && flag "config.json с записью i18n ru-RU" "$N" bad || say "config.json с записью i18n ru-RU" "0"
say "язык пользователя (ugos.lang, uid 1000)" "$(cat /ugreen/.config/.nas/1000/ugos.lang 2>/dev/null || echo '?')"

echo; echo "=== Оболочка (фронтенд) ==="
N=0; for f in $(find $R1 $R2 -path '*/www/*' -name 'ugos-framework-*.js' -not -path '*node_modules*' 2>/dev/null); do
  grep -qaE 'switchLang\([a-z],?[a-z]?(=!1)?\)\{ [a-z]=(\(![a-z]\|\|[a-z]==="en-US"\)\?)?"ru-RU"' "$f" && N=$((N+1)); done
[ "$N" -gt 0 ] && flag "framework с нашей подменой языка" "$N" bad || say "framework с нашей подменой языка" "0"
L=$(find $R1 $R2 \( -name '*.ruorig' -o -name '*.bak' -o -name '*.bak.gz' -o -name '*.br.stale' \) \( -path '*/www/*' -o -path '*/onlyoffice/*' \) -not -path '*node_modules*' -not -path '*.db/*' 2>/dev/null)
N=$(echo "$L" | grep -c .)
if [ "$N" -gt 0 ]; then flag "резервные копии и остатки (.ruorig/.bak/.br.stale)" "$N" bad; echo "$L" | sed 's/^/     /'; else say "резервные копии и остатки (.ruorig/.bak/.br.stale)" "0"; fi
ALL=$(find $R1 $R2 -path '*/locale/ru-RU.json' -not -path '*onlyoffice*' 2>/dev/null)
TOT=$(echo "$ALL" | grep -c . ); EMP=0; for f in $ALL; do [ "$(tr -d ' \n' < "$f")" = "{}" ] && EMP=$((EMP+1)); done
say "ru-RU.json: всего / пустых заглушек / с переводом" "$TOT / $EMP / $((TOT-EMP))"
N=0; for f in $(find $R1 $R2 -path '*/locale/en-US.json' -not -path '*onlyoffice*' 2>/dev/null); do grep -qaP '[А-Яа-яЁё]' "$f" && { N=$((N+1)); echo "   !! кириллица в английском файле: $f"; }; done
[ "$N" -gt 0 ] && flag "en-US.json с русским текстом (подмена английского)" "$N" bad || say "en-US.json с русским текстом (подмена английского)" "0"

echo; echo "=== Online Office ==="
[ -d "$OFF" ] || say "Online Office" "не установлен"
if [ -d "$OFF" ]; then
  grep -q 'URLSearchParams' $ODS/api/documents/api.js 2>/dev/null && flag "api.js: наша правка языка" "ЕСТЬ" bad || say "api.js: наша правка языка" "нет"
  grep -q 'params += "&lang=ru-RU"' $ODS/api/documents/api.js 2>/dev/null && flag "api.js: старая жёсткая подмена ru-RU" "ЕСТЬ" bad || say "api.js: старая жёсткая подмена ru-RU" "нет"
  grep -q 'appOptions.region="ru-ru"' $ODS/spreadsheeteditor/main/app.js 2>/dev/null && flag "app.js: жёсткий регион ru-ru" "ЕСТЬ" bad || say "app.js: жёсткий регион ru-ru" "нет"
  grep -q 'appOptions.lang="ru-RU"\|appOptions.lang=(new URL\|appOptions.lang=(function' $ODS/spreadsheeteditor/main/app.js 2>/dev/null && flag "app.js: наша правка языка" "ЕСТЬ" bad || say "app.js: наша правка языка" "нет"
  [ -f $OFF/www/locale/ru-RU.json ] && flag "www/locale/ru-RU.json (Office)" "есть (наш)" bad || say "www/locale/ru-RU.json (Office)" "нет"
  [ -f $OFF/www/locale/en-US.json ] && say "www/locale/en-US.json (Office)" "на месте" || flag "www/locale/en-US.json (Office)" "ОТСУТСТВУЕТ (окно будет пустым)" bad
fi

echo; echo "=== Автозапуск и состояние ==="
for u in ugos-russify ugos-office-russify; do systemctl list-unit-files 2>/dev/null | grep -q "^$u.timer" && flag "таймер $u" "ЕСТЬ" bad || say "таймер $u" "нет"; done
[ -d /volume1/ugos-russify ] && say "папка /volume1/ugos-russify" "есть: $(ls /volume1/ugos-russify | tr '\n' ' ')" || say "папка /volume1/ugos-russify" "нет"

echo
if [ "$BAD" -eq 0 ]; then echo "ИТОГ: система чистая, следов русификации нет."; else echo "ИТОГ: найдено следов: $BAD. Откат: sudo bash russify.sh --revert (если следы остались, переустановите приложение из Центра приложений)."; fi
