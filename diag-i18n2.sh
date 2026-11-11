#!/bin/bash
# Диагностика 2: полные en-US записи i18n и формат config.json (только чтение). Результат: ~/diag-i18n2.txt
if [ "$(id -u)" -ne 0 ]; then echo "Запусти с sudo: sudo bash $0"; exit 1; fi
U="${SUDO_USER:-root}"; H="$(getent passwd "$U" | cut -d: -f6)"; OUT="${H:-/root}/diag-i18n2.txt"
python3 - /ugreen/@appstore /volume1/@appstore > "$OUT" << 'PY'
import glob, json, os, sys
first = True
for base in sys.argv[1:]:
    for c in sorted(glob.glob(os.path.join(base, "*", "config.json"))):
        raw = open(c, encoding="utf-8").read()
        if first:
            print("## ФОРМАТ", c, "размер", len(raw), "переводов строк", raw.count("\n"))
            print(raw[:200].replace("\n", "\\n")); first = False
        try: d = json.loads(raw)
        except Exception as e: print("## ОШИБКА", c, e); continue
        print("## ", c.split("/")[-2], "| ru уже есть:", any(x.get("langName") == "ru-RU" for x in d.get("i18n") or []))
        for x in d.get("i18n") or []:
            if x.get("langName") == "en-US":
                print(json.dumps({k: v for k, v in x.items() if k in ("name", "description", "tags")}, ensure_ascii=False))
        extra = [k for k in d if k not in ("appId","icon","iconModifyTimeSec","version","appType","arch","daemon","aloneModule","serviceName","managerType","route","pkgType","category","languageList","accessList","isDockerApp","i18n","installExclusive","installParameters","accessCtrl","baseAccessInfo","accessCtrlV2","allowAddAccessPath","tagTypes","publisherType","searchServiceAddress","subApps","parentAppID","parentAppName")]
        if extra: print("доп.ключи:", extra)
PY
echo "Готово: $OUT"; wc -c "$OUT"
