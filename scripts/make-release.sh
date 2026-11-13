#!/bin/bash
set -euo pipefail

# lightdao release helper: 交互式创建规范的 annotated tag 并触发 CI 发布
# 用法：./scripts/make-release.sh [version] [--push]
#   version: 如 1.4.8，自动加 v 前缀
#   --push: 立即推送到远端触发 CI（默认先在本地预览）

VERSION="${1:-}"
PUSH_FLAG="${2:-}"

if [ -z "$VERSION" ]; then
  echo "用法: $0 <version> [--push]"
  echo "示例: $0 1.4.8        # 本地创建 v1.4.8"
  echo "      $0 1.4.8 --push # 创建并推送到远端"
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
  read -p "   继续吗？(y/N) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# 准备 changelog 模板
CHANGELOG_FILE="/tmp/lightdao-release-$TAG_NAME.md"
cat > "$CHANGELOG_FILE" <<'TEMPLATE'
本次版本的一句话总结（会作为 release 标题下方的摘要）

## Features
* 新功能描述

## Bug Fixes
* 修复的问题

## Chore & CI
* 构建/工具链改进

---
# 编辑完成后保存并关闭编辑器
# 空行和注释（以 # 开头的行）会被自动删除
# 每个条目用 * 开头（markdown 列表）
# 可以引用 PR/issue，但用 PR #123 / issue #456 格式（带空格），避免 GitHub 自动链接
TEMPLATE

# 打开编辑器
EDITOR="${EDITOR:-vim}"
$EDITOR "$CHANGELOG_FILE"

# 规范化 changelog：删注释、删空开头结尾、统一换行
NORMALIZED="$(grep -v '^#' "$CHANGELOG_FILE" | grep -v '^---' | tr -d '\r' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

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

if [ "$PUSH_FLAG" != "--push" ]; then
  read -p "创建 tag 到本地？(Y/n) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Nn]$ ]] && exit 0
fi

# 创建 annotated tag
git tag -a "$TAG_NAME" -m "$NORMALIZED"
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
