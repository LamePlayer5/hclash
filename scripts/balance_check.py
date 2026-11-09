#!/usr/bin/env python3
"""括号配对精确检查：先剥离字符串（含模板字面量与其中 ${}），再剥离注释，输出不平衡行号。"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")


def scan(path):
    text = open(path, encoding="utf-8").read()
    out = []
    i, n = 0, len(text)
    state = None  # None | "'" | '"' | '`' | '//' | '/*'
    tpl_depth = []  # 模板字面量中 ${ 的嵌套栈
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state is None:
            if c == "'" or c == '"' or c == "`":
                state = c
                if c == "`":
                    tpl_depth.append(0)
                i += 1
                continue
            if c == "/" and nxt == "/":
                state = "//"
                i += 2
                continue
            if c == "/" and nxt == "*":
                state = "/*"
                i += 2
                continue
            out.append(c)
            i += 1
            continue
        if state in ("'", '"'):
            if c == "\\":
                i += 2
                continue
            if c == state:
                state = None
            i += 1
            continue
        if state == "`":
            if c == "\\":
                i += 2
                continue
            if c == "$" and nxt == "{":
                tpl_depth[-1] += 1
                out.append("{")  # ${ 的 { 计入配对
                i += 2
                continue
            if c == "}" and tpl_depth and tpl_depth[-1] > 0:
                tpl_depth[-1] -= 1
                out.append("}")
                i += 1
                continue
            if c == "`":
                tpl_depth.pop()
                state = None
            i += 1
            continue
        if state == "//":
            if c == "\n":
                state = None
                out.append("\n")
            i += 1
            continue
        if state == "/*":
            if c == "*" and nxt == "/":
                state = None
                i += 2
                continue
            i += 1
    return "".join(out)


def check(path):
    src = scan(path)
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    line = 1
    issues = []
    for ch in src:
        if ch == "\n":
            line += 1
        elif ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                issues.append(f"line {line}: unexpected '{ch}'")
            else:
                stack.pop()
    for ch, ln in stack:
        issues.append(f"line {ln}: unclosed '{ch}'")
    return issues


total = 0
bad = 0
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", "tools", "node_modules")]
    for fn in filenames:
        if not fn.endswith((".ets", ".ts")):
            continue
        p = os.path.join(dirpath, fn)
        total += 1
        issues = check(p)
        if issues:
            bad += 1
            print(os.path.relpath(p, ROOT))
            for x in issues:
                print("   ", x)
print(f"checked {total} files, {bad} with issues")
sys.exit(1 if bad else 0)
