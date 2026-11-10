#!/bin/bash
# Диагностика русификации оболочки UGOS (ТОЛЬКО ЧТЕНИЕ). Лог: ~/diag-shell.log
#   sudo bash diag-shell.sh
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"
LOG="${LOG:-${H:-/root}/diag-shell.log}"
exec > >(tee "$LOG") 2>&1
B=/ugreen/@appstore
for a in com.ugreen.logmgr com.ugreen.taskmgr; do
  W="$B/$a/www"
  echo "=============== $a"
  ls -la "$W" "$W/locale" 2>&1 | head -40
  echo "--- файлы с switchLang:"
  grep -rl "switchLang" "$W" --include=*.js 2>/dev/null
  echo "--- ugos-framework:"
  ls -la "$W"/assets/ugos-framework-* 2>&1
  for f in "$W"/assets/ugos-framework-*.js; do
    [ -f "$f" ] || continue
    echo "patched: $(grep -c 'switchLang(e,t=!1){ e="ru-RU"' "$f")  (1 = патч есть)"
    echo "gz == js: $( [ -f "$f.gz" ] && { [ "$(gzip -dc "$f.gz" | sha256sum)" = "$(sha256sum < "$f")" ] && echo да || echo НЕТ; } )"
    grep -o 'async switchLang([^)]*){[^;]\{0,60\}' "$f" | head -2
  done
  echo "--- как грузится locale в index.html:"
  grep -o 'locale[^"]\{0,60\}' "$W/index.html" 2>/dev/null | head -5
  echo "--- LANG в js других приложений (customI18nLoad / locale/):"
  grep -rho 'customI18nLoad[^;]\{0,60\}' "$W" --include=*.js 2>/dev/null | sort -u | head -5
done
echo "=============== манифест"
cat /volume1/ugos-russify/shell-manifest.txt 2>&1
echo "=============== веб-сервер / кеш"
ls /ugreen/@appstore/com.ugreen.logmgr/http.d 2>&1; cat /ugreen/@appstore/com.ugreen.logmgr/http.d/* 2>&1 | head -40
echo; echo "Готово. Ничего не менялось. Лог: $LOG"
sleep 0.5; [ -n "$SUDO_USER" ] && chown "$SUDO_USER" "$LOG" 2>/dev/null
