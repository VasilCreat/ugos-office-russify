#!/bin/bash
# Только чтение (работает с копией): где в базах приложений хранятся названия (Online Office / 온라인 문서).
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
T=$(mktemp -d); trap 'rm -rf $T' EXIT
for f in /etc/nas_appstore/state/appstore_app.db /etc/nas_appstore/state/appstore_appruntime.db; do
  [ -f "$f" ] || continue
  b=$(basename $f); cp "$f" $T/$b; [ -f "$f-wal" ] && cp "$f-wal" $T/$b-wal; [ -f "$f-shm" ] && cp "$f-shm" $T/$b-shm
  echo "## $f ($(stat -c %y $f | cut -c1-19))"
  python3 - $T/$b << 'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
pats = ["Online Office", "온라인 문서", "Онлайн-офис", "\\uc628\\ub77c\\uc778", "ko-KR"]
tabs = [r[0] for r in db.execute("select name from sqlite_master where type='table'")]
print("  таблицы:", ", ".join(tabs))
for t in tabs:
    cols = [r[1] for r in db.execute('pragma table_info("%s")' % t)]
    try: rows = db.execute('select * from "%s"' % t).fetchall()
    except Exception as e: print("  ошибка", t, e); continue
    hits = 0
    for row in rows:
        for c, v in zip(cols, row):
            s = v.decode("utf-8", "replace") if isinstance(v, bytes) else (v if isinstance(v, str) else "")
            for p in pats:
                i = s.find(p)
                if i >= 0 and hits < 3:
                    hits += 1
                    print("  [%s.%s] %r ... %s" % (t, c, p, s[max(0, i-100):i+160].replace("\n", " ")))
                    break
PY
done
echo "## PostgreSQL"; (command -v psql >/dev/null && ls /var/lib/postgresql 2>/dev/null | head) || echo "psql нет в PATH"
