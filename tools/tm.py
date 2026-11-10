#!/usr/bin/env python3
"""Пайплайн перевода (память переводов tm/ru.json: английская строка -> русская).

  tm.py seed  <en_root> <ru_root>        пары из уже готовых ru-RU.json
  tm.py next  <en_root> [N]              следующие N непереведённых строк -> batch.json (нужен перевод)
  tm.py add   <batch.json> <ru.json>     добавить перевод пачки (массив русских строк по порядку)
  tm.py build <en_root> <ru_root>        собрать ru/**/ru-RU.json из памяти (+ ru/MANIFEST)
  tm.py stat  <en_root>                  сколько переведено

en_root = каталог со снимком английских файлов (ugreen/@appstore/..., volume1/@appstore/...)
Строки без перевода остаются английскими. Плейсхолдеры проверяются при add/build.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TM = os.path.join(HERE, "..", "tm", "ru.json")
# порядок приоритета: что видно чаще всего
PRIO = ["com.ugreen.ctlmgr", "com.ugreen.filemgr", "com.ugreen.storagemgr", "com.ugreen.appmgr",
        "com.ugreen.docker", "com.ugreen.syncbackup", "com.ugreen.office", "com.ugreen.music",
        "com.ugreen.aiconsole", "com.ugreen.kvm", "com.ugreen.versionmgr", "com.ugreen.helpmgr",
        "com.ugreen.globalsearch", "com.ugreen.desktop", "com.ugreen.editor"]

def load_tm():
    return json.load(open(TM, encoding="utf-8")) if os.path.exists(TM) else {}

def save_tm(t):
    os.makedirs(os.path.dirname(TM), exist_ok=True)
    json.dump(t, open(TM, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)

def ph(s):
    return sorted(re.findall(r"\{[^}]*\}|%[sd]|<[^>]+>|\$\{[^}]*\}", s))

def en_files(root):
    out = []
    for dp, dns, fns in os.walk(root):
        if "en-US.json" in fns and os.path.basename(dp) == "locale":
            out.append(os.path.join(dp, "en-US.json"))
    def key(p):
        for i, a in enumerate(PRIO):
            if "/" + a + "/" in p: return (i, p)
        return (99, p)
    return sorted(out, key=key)

def strings(o, out):
    if isinstance(o, dict):
        for v in o.values(): strings(v, out)
    elif isinstance(o, str): out.append(o)

def flat(o, p=""):
    r = {}
    for k, v in o.items():
        q = p + "." + k if p else k
        if isinstance(v, dict): r.update(flat(v, q))
        else: r[q] = v
    return r

def translate(o, tm, miss):
    if isinstance(o, dict): return {k: translate(v, tm, miss) for k, v in o.items()}
    if isinstance(o, str):
        if o in tm: return tm[o]
        if o.strip() and re.search(r"[A-Za-z]", o): miss.add(o)
        return o
    return o

cmd = sys.argv[1]
if cmd == "seed":
    en_root, ru_root = sys.argv[2:4]
    tm = load_tm(); n = 0
    for f in en_files(en_root):
        rel = os.path.relpath(f, en_root); rf = os.path.join(ru_root, rel.replace("@appstore/", "").replace("en-US.json", "ru-RU.json"))
        if not os.path.exists(rf): continue
        e = flat(json.load(open(f, encoding="utf-8"))); r = flat(json.load(open(rf, encoding="utf-8")))
        for k, v in e.items():
            if isinstance(v, str) and k in r and r[k] != v and v not in tm and ph(v) == ph(r[k]):
                tm[v] = r[k]; n += 1
    save_tm(tm); print("добавлено в память:", n, "всего:", len(tm))
elif cmd == "next":
    en_root = sys.argv[2]; N = int(sys.argv[3]) if len(sys.argv) > 3 else 300
    tm = load_tm(); seen = []; s = set()
    for f in en_files(en_root):
        o = []; strings(json.load(open(f, encoding="utf-8")), o)
        for x in o:
            if x not in tm and x not in s and x.strip() and re.search(r"[A-Za-z]", x):
                s.add(x); seen.append(x)
            if len(seen) >= N: break
        if len(seen) >= N: break
    json.dump(seen, open("batch.json", "w", encoding="utf-8"), ensure_ascii=False)
    for i, x in enumerate(seen): print(i, json.dumps(x, ensure_ascii=False))
    print("--- в пачке:", len(seen), file=sys.stderr)
elif cmd == "add":
    batch = json.load(open(sys.argv[2], encoding="utf-8")); ru = json.load(open(sys.argv[3], encoding="utf-8"))
    if len(batch) != len(ru): sys.exit("ДЛИНА: en %d != ru %d" % (len(batch), len(ru)))
    tm = load_tm(); bad = 0
    for e, r in zip(batch, ru):
        if ph(e) != ph(r): print("ПЛЕЙСХОЛДЕРЫ:", json.dumps(e, ensure_ascii=False), "->", json.dumps(r, ensure_ascii=False)); bad += 1; continue
        tm[e] = r
    save_tm(tm); print("добавлено:", len(batch) - bad, "ошибок:", bad, "всего в памяти:", len(tm))
elif cmd == "build":
    en_root, ru_root = sys.argv[2:4]; tm = load_tm(); man = []; allmiss = set(); tot = 0
    for f in en_files(en_root):
        rel = os.path.relpath(f, en_root); out = os.path.join(ru_root, rel.replace("@appstore/", "").replace("en-US.json", "ru-RU.json"))
        miss = set(); res = translate(json.load(open(f, encoding="utf-8")), tm, miss)
        o = []; strings(res, o)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        json.dump(res, open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        allmiss |= miss; tot += 1
        man.append(os.path.relpath(out, ru_root))
        print("%4d без перевода  %s" % (len(miss), rel)) if miss else None
    open(os.path.join(ru_root, "MANIFEST"), "w").write("\n".join(sorted(man)) + "\n")
    print("файлов:", tot, "строк без перевода (уникальных):", len(allmiss))
elif cmd == "stat":
    tm = load_tm(); s = set()
    for f in en_files(sys.argv[2]):
        o = []; strings(json.load(open(f, encoding="utf-8")), o); s |= {x for x in o if x.strip() and re.search(r"[A-Za-z]", x)}
    print("уникальных строк:", len(s), "переведено:", sum(1 for x in s if x in tm), "осталось:", sum(1 for x in s if x not in tm))
