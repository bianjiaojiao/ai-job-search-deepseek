#!/usr/bin/env bash
# 把 DeepSeek(DSH) 适配层安装成用户级技能（macOS / Linux / WSL）
#
# 用法：
#   ./dsh/install.sh                  # 仓库根默认是本脚本的上一级
#   ./dsh/install.sh -r /path/to/repo # 指定仓库
#   ./dsh/install.sh -f               # 覆盖已存在的同名文件
#   ./dsh/install.sh -e               # 顺便把 AI_JOB_SEARCH_REPO 写进 shell profile
#
# 只拷贝文件、记录仓库路径、做环境自检；不删除任何文件、不联网。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${HOME}/.dsh/skills/ai-job-search"
FORCE=0
SETENV=0

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while getopts "r:t:feh" opt; do
  case "$opt" in
    r) REPO="$OPTARG" ;;
    t) TARGET="$OPTARG" ;;
    f) FORCE=1 ;;
    e) SETENV=1 ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done

if [ ! -f "$REPO/tools/verify_pdf.py" ]; then
  echo "这个目录看起来不是 ai-job-search 仓库（缺 tools/verify_pdf.py）: $REPO" >&2
  exit 1
fi

if [ -e "$TARGET" ] && [ "$FORCE" -ne 1 ]; then
  echo "目标已存在: $TARGET"
  echo "重装请加 -f（只覆盖同名文件，不删除其它文件）。"
  exit 1
fi

mkdir -p "$TARGET"
cp -f "$SCRIPT_DIR/SKILL.md" "$TARGET/"
for d in references scripts; do
  [ -d "$SCRIPT_DIR/$d" ] && cp -Rf "$SCRIPT_DIR/$d" "$TARGET/"
done
printf '%s\n' "$REPO" > "$TARGET/repo.txt"

echo "  + SKILL.md / references / scripts / repo.txt"
echo "  + repo.txt -> $REPO"

if [ "$SETENV" -eq 1 ]; then
  LINE="export AI_JOB_SEARCH_REPO=\"$REPO\""
  for prof in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -e "$prof" ] || continue
    grep -qF 'AI_JOB_SEARCH_REPO' "$prof" || printf '\n%s\n' "$LINE" >> "$prof"
  done
  echo "  + 已写入 shell profile（新开终端生效）"
fi

echo ""
echo "环境自检："
probe() {
  local name="$1" hint="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    printf '  [OK]   %s\n' "$name"
  else
    printf '  [MISS] %s  → %s\n' "$name" "$hint"
  fi
}
probe "python3" "安装 Python 3.10+" command -v python3
probe "pypdf" "python3 -m pip install pypdf" python3 -c "import pypdf"
probe "bun" "https://bun.sh" command -v bun
probe "lualatex" "安装 TeX Live / MacTeX（CV 用）" command -v lualatex
probe "xelatex" "安装 TeX Live / MacTeX（求职信、中文模板用）" command -v xelatex
probe "门户 CLI 依赖" "在仓库根执行 python3 tools/install_portal_clis.py" test -d "$REPO/.agents/skills/freehire-search/cli/node_modules"

echo ""
echo "完成。技能已装到: $TARGET"
echo "DSH 会话里说「用 ai-job-search 帮我…」即可触发。"
echo "提示：本技能自带的三个便捷脚本是 PowerShell（.ps1），需要 pwsh；没有 pwsh 时按 SKILL.md §2 直接调用 bun/python 等价命令。"
