#!/usr/bin/env python3
"""Проверка перевода: те же ключи и те же плейсхолдеры, что в en-US.json.
Использование: tools_check_ru.py en-US.json ru-RU.json"""
import json, re, sys
def flat(o, p=""):
    r = {}
    for k, v in o.items():
        q = p + "." + k if p else k
        if isinstance(v, dict): r.update(flat(v, q))
        else: r[q] = v
    return r
en = flat(json.load(open(sys.argv[1], encoding="utf-8")))
ru = flat(json.load(open(sys.argv[2], encoding="utf-8")))
ph = lambda s: sorted(re.findall(r"\{[^}]*\}|%[sd]|<[^>]+>", s)) if isinstance(s, str) else []
bad = 0
for k in en:
    if k not in ru: print("НЕТ ключа:", k); bad += 1
    elif ph(en[k]) != ph(ru[k]): print("ПЛЕЙСХОЛДЕРЫ:", k, ph(en[k]), ph(ru[k])); bad += 1
for k in ru:
    if k not in en: print("ЛИШНИЙ ключ:", k); bad += 1
print("ключей:", len(en), "ошибок:", bad)
sys.exit(1 if bad else 0)
