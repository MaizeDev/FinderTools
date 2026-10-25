#!/usr/bin/env bash
# 安装打包用工具 dmgbuild（只需联网执行一次）。
# 所有文件都落在仓库内的 .build/ 目录（已被 .gitignore 忽略），
# 不使用 sudo，不写入系统 Python，也不写入 ~/Library。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.build/dmg-venv"
CACHE_DIR="$ROOT_DIR/.build/pip-cache"

if [[ "$VENV_DIR" != "$ROOT_DIR/.build/dmg-venv" ]]; then
  echo "错误：虚拟环境路径不符合预期：$VENV_DIR" >&2
  exit 1
fi

if [[ -x "$VENV_DIR/bin/dmgbuild" ]]; then
  echo "dmgbuild 已安装：$("$VENV_DIR/bin/python" -c 'import dmgbuild; print(dmgbuild.__version__)' 2>/dev/null || echo "版本未知")"
  echo "位置：$VENV_DIR"
  exit 0
fi

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "错误：找不到 Python 解释器“$PYTHON”。可用 PYTHON=/path/to/python3 ./script/dmg/setup.sh 指定。" >&2
  exit 2
fi

echo "使用 $("$PYTHON" -V 2>&1) 创建虚拟环境：$VENV_DIR"
"$PYTHON" -m venv "$VENV_DIR"
mkdir -p "$CACHE_DIR"

echo "从 pypi.org 安装 dmgbuild（需要联网）……"
PIP_CACHE_DIR="$CACHE_DIR" "$VENV_DIR/bin/python" -m pip install --disable-pip-version-check dmgbuild

echo "完成：$("$VENV_DIR/bin/python" -c 'import dmgbuild; print("dmgbuild " + dmgbuild.__version__)' 2>/dev/null || echo "dmgbuild 已安装")"
echo "打包脚本会自动使用：$VENV_DIR/bin/dmgbuild"
