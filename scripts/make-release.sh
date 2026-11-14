#!/bin/bash
set -euo pipefail

# lightdao release helper: 创建规范的 annotated tag 并触发 CI 发布
# 用法：
#   ./scripts/make-release.sh <version> [--push] [--body <text>] [--body-file <path>]
#   ./scripts/make-release.sh 1.4.8                    # 交互式填写
#   ./scripts/make-release.sh 1.4.8 --body "..."       # 直接指定内容（agent 友好）
#   ./scripts/make-release.sh 1.4.8 --body-file /tmp/changelog.md --push

VERSION=""
PUSH_FLAG=""
BODY_TEXT=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH_FLAG="--push"; shift ;;
    --body) BODY_TEXT="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) VERSION="$1"; shift ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "用法: $0 <version> [--push] [--body <text>] [--body-file <path>]"
  echo "示例: $0 1.4.8                        # 交互式"
  echo "      $0 1.4.8 --body 'Fix bug'       # agent 调用"
  echo "      $0 1.4.8 --body-file /tmp/cl.md # 从文件读"
  exit 1
fi

# 规范化版本号
if [[ "$VERSION" =~ ^v ]]; then
  TAG_NAME="$VERSION"
  VERSION="${VERSION#v}"
else
  TAG_NAME="v$VERSION"
fi

# 检查是否已存在
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  echo "❌ Tag $TAG_NAME 已存在"
  echo "   用 git tag -d $TAG_NAME 删除本地 tag"
  echo "   或 git push origin :refs/tags/$TAG_NAME 删除远端 tag"
  exit 1
fi

# 检查工作区
if ! git diff-index --quiet HEAD --; then
  echo "❌ 工作区有未提交的改动，请先 commit"
  git status --short
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "master" ]; then
  echo "⚠️  当前分支是 $CURRENT_BRANCH，不是 master"
  if [ -z "$BODY_TEXT" ] && [ -z "$BODY_FILE" ]; then
    read -p "   继续吗？(y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
  else
    echo "   非交互模式，继续执行"
  fi
fi

# 获取 changelog
if [ -n "$BODY_FILE" ]; then
  # 从文件读取
  if [ ! -f "$BODY_FILE" ]; then
    echo "❌ 文件不存在: $BODY_FILE"
    exit 1
  fi
  NORMALIZED="$(grep -v '^---' "$BODY_FILE" | tr -d '\r' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
elif [ -n "$BODY_TEXT" ]; then
  # 从参数读取（agent 友好）
  NORMALIZED="$(printf '%s' "$BODY_TEXT" | tr -d '\r' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
else
  # 交互式编辑
  CHANGELOG_FILE="/tmp/lightdao-release-$TAG_NAME.md"
  cat > "$CHANGELOG_FILE" <<'TEMPLATE'
本次版本的一句话总结（会作为 release 标题下方的摘要）

## Features
* 新功能描述

## Bug Fixes
* 修复的问题

## Chore & CI
* 构建/工具链改进
TEMPLATE

  echo "提示：编辑完成后保存并关闭编辑器。"
  echo "      每个条目用 * 开头；Markdown 标题（## 小标题）会原样保留在 tag 正文里。"
  echo "      引用 PR/issue 时写成「PR N」「issue N」（不要带 #），避免 GitHub 自动链接。"
  echo "      仅 '---' 分隔行和末尾空行会被丢弃。"

  EDITOR="${EDITOR:-vim}"
  $EDITOR "$CHANGELOG_FILE"
  NORMALIZED="$(grep -v '^---' "$CHANGELOG_FILE" | tr -d '\r' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
fi

if [ -z "$NORMALIZED" ]; then
  echo "❌ Changelog 为空，取消发布"
  exit 1
fi

# 预览
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tag: $TAG_NAME"
echo "Commit: $(git rev-parse --short HEAD) $(git log -1 --format='%s')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$NORMALIZED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$PUSH_FLAG" != "--push" ] && [ -z "$BODY_TEXT" ] && [ -z "$BODY_FILE" ]; then
  read -p "创建 tag 到本地？(Y/n) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Nn]$ ]] && exit 0
fi

# 创建 annotated tag
# 用 --cleanup=verbatim 从临时文件写入，避免默认 cleanup 删掉以 # 开头的行（Markdown 标题）
BODY_TMP="$(mktemp -t lightdao-release-body.XXXXXX)"
trap 'rm -f "$BODY_TMP"' EXIT
printf '%s\n' "$NORMALIZED" > "$BODY_TMP"
git tag -a "$TAG_NAME" --cleanup=verbatim -F "$BODY_TMP"
echo "✓ Tag $TAG_NAME 已创建"

if [ "$PUSH_FLAG" = "--push" ]; then
  echo "推送到 origin..."
  git push origin "$TAG_NAME"
  echo "✓ 已推送，CI 正在构建..."
  echo "  查看进度: gh run list --workflow main.yaml --limit 3"
  echo "  查看 release: gh release view $TAG_NAME --web"
else
  echo ""
  echo "下一步："
  echo "  git push origin $TAG_NAME  # 推送到远端触发 CI"
  echo "  或重新运行: $0 $VERSION --push"
fi
