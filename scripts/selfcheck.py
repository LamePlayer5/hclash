#!/usr/bin/env python3
"""HClash 仓库静态自检（无 DevEco 环境下的基础校验）。

检查项：
1. import 的相对路径目标文件存在
2. 每个 view/page 文件含 build() 与 struct 声明
3. JSON/JSON5 文件语法（去注释与尾逗号后）
（括号配对请使用 balance_check.py，其对字符串/模板/正则的处理更精确）
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
problems = []


def check_imports(path):
    base = os.path.dirname(path)
    for m in re.finditer(r"from\s+'([^']+)'", open(path, encoding="utf-8").read()):
        spec = m.group(1)
        if spec.startswith("."):
            target = os.path.normpath(os.path.join(base, spec))
            found = any(os.path.exists(target + ext) for ext in (".ets", ".ts", ""))
            if not found:
                problems.append(f"{path}: import target missing: {spec}")


def check_structure(path):
    text = open(path, encoding="utf-8").read()
    if "/views/" in path.replace("\\", "/") or "/pages/" in path.replace("\\", "/"):
        if "struct" not in text:
            problems.append(f"{path}: no struct declaration")
        if "build()" not in text:
            problems.append(f"{path}: no build()")


def check_json(path):
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"//[^\n]*", "", text)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    try:
        json.loads(text)
    except Exception as e:
        problems.append(f"{path}: invalid json: {e}")


count = 0
for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT)):
    dirnames[:] = [d for d in dirnames if d not in (".git", "tools", "node_modules", "oh_modules")]
    for fn in filenames:
        p = os.path.join(dirpath, fn)
        rel = os.path.relpath(p, ROOT)
        if fn.endswith(".ets") or fn.endswith(".ts"):
            check_imports(p)
            check_structure(p)
            count += 1
        elif fn.endswith(".json") or fn.endswith(".json5"):
            check_json(p)
            count += 1

print(f"checked {count} files")
if problems:
    print(f"{len(problems)} problem(s):")
    for x in problems:
        print(" -", x)
    sys.exit(1)
print("all checks passed")
