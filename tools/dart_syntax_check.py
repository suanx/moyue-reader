#!/usr/bin/env python3
"""用 tree-sitter 的 Dart 语法解析器对所有 .dart 文件做语法校验。
能捕获：语法错误、括号/引号不匹配、结构残缺等。
无法捕获：类型错误、未定义符号（需真实 Dart 编译器）。
"""
import os
import sys

import tree_sitter_dart
from tree_sitter import Language, Parser

LANG = Language(tree_sitter_dart.language())
PARSER = Parser(LANG)

BOLD = "\033[1m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RESET = "\033[0m"


def check_file(path):
    src = open(path, "rb").read()
    tree = PARSER.parse(src)
    errors = []

    def walk(node):
        if node.type == "ERROR" or node.is_missing:
            line = node.start_point[0] + 1
            col = node.start_point[1] + 1
            snippet = src[node.start_byte:node.end_byte].decode("utf-8", "replace")
            snippet = snippet[:60].replace("\n", "\\n")
            errors.append((line, col, node.type, snippet))
        for child in node.children:
            walk(child)

    walk(tree.root_node)
    return errors


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "/data/workspace/moyue_reader"
    files = []
    for sub in ("lib", "test"):
        d = os.path.join(root, sub)
        if not os.path.isdir(d):
            continue
        for dirpath, _, names in os.walk(d):
            for n in sorted(names):
                if n.endswith(".dart"):
                    files.append(os.path.join(dirpath, n))
    files.sort()

    total_err = 0
    bad = []
    for f in files:
        errs = check_file(f)
        rel = os.path.relpath(f, root)
        if errs:
            bad.append((rel, errs))
            total_err += len(errs)
            print(f"{RED}✗{RESET} {rel}")
            for line, col, kind, snip in errs[:5]:
                print(f"    L{line}:{col}  [{kind}]  {snip}")
            if len(errs) > 5:
                print(f"    ... 另有 {len(errs) - 5} 处")
        else:
            print(f"{GREEN}✓{RESET} {rel}")

    print()
    if total_err == 0:
        print(f"{BOLD}{GREEN}全部 {len(files)} 个 Dart 文件语法校验通过{RESET}")
    else:
        print(f"{BOLD}{RED}发现 {total_err} 处语法问题，涉及 {len(bad)} 个文件{RESET}")
        for rel, errs in bad:
            print(f"  - {rel}: {len(errs)} 处")
    return 1 if total_err else 0


if __name__ == "__main__":
    sys.exit(main())
