#!/bin/bash
# ============================================================
# Antigravity 应用图标切换脚本（深色模式友好版）
#
# 用法:
#   ./apply-icon.sh              # 列出所有可选变体
#   ./apply-icon.sh A            # 应用「A 炭黑」变体
#   ./apply-icon.sh restore      # 还原官方原版图标
#
# 说明:
#   - 首次替换会自动把原 icon.icns 备份为 icon.icns.orig
#   - 脚本会清隔离属性 + ad-hoc 重签名 + 刷新 Dock 图标缓存
#   - 往 /Applications/*.app 内部写文件是 macOS App Management 保护范围，
#     所以需要在「终端」里运行（脚本会自动 exec sudo 提权）
# ============================================================
set -euo pipefail

APP="/Applications/Antigravity.app"
RES="$APP/Contents/Resources"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICNS_DIR="$HERE/icons"
BACKUP="$RES/icon.icns.orig"

ARG="${1:-}"

# ---------- 列出变体（不需要提权，放在 sudo 之前）----------
if [ -z "$ARG" ]; then
  echo ""
  echo "可选变体:"
  ls -1 "$ICNS_DIR" 2>/dev/null | sed 's/\.icns$//' | sed 's/^/  /'
  echo ""
  echo "  restore   —— 还原官方原版"
  echo ""
  echo "用法示例:  ./apply-icon.sh G      （G = Gemini 同款，推荐）"
  echo ""
  exit 0
fi

# ---------- 校验变体存在（同样不需要提权）----------
if [ "$ARG" != "restore" ]; then
  if ! ls -1 "$ICNS_DIR"/"$ARG"*.icns >/dev/null 2>&1; then
    echo "✗ 找不到变体「${ARG}」，可用的有:"
    ls -1 "$ICNS_DIR" 2>/dev/null | sed 's/^/  /'
    exit 1
  fi
fi

# ---------- 提权 ----------
if [ "$(id -u)" -ne 0 ]; then
  echo "→ 需要写入 $APP 内部，正在提权（请输入密码）..."
  exec /usr/bin/sudo -p "[sudo] 密码: " /bin/bash "$0" "${1:-}"
fi

# ---------- 备份原版 ----------
if [ ! -f "$BACKUP" ]; then
  echo "→ 备份原版图标 → icon.icns.orig"
  cp "$RES/icon.icns" "$BACKUP"
else
  echo "→ 原版备份已存在，跳过（icon.icns.orig）"
fi

# ---------- 选择要应用的 icns ----------
if [ "$ARG" = "restore" ]; then
  SRC="$BACKUP"
  echo "→ 还原官方原版图标"
else
  SRC="$(ls -1 "$ICNS_DIR"/"$ARG"*.icns 2>/dev/null | head -1 || true)"
  if [ -z "$SRC" ]; then
    echo "✗ 找不到变体「${ARG}」，可用的有:"
    ls -1 "$ICNS_DIR" 2>/dev/null | sed 's/^/  /'
    exit 1
  fi
  echo "→ 应用变体: $(basename "$SRC")"
fi

# ---------- 校验 icns 有效性 ----------
if ! /usr/bin/sips -g pixelWidth "$SRC" >/dev/null 2>&1; then
  echo "✗ icns 文件无效: $SRC"
  exit 1
fi

# ---------- 替换 ----------
cp "$SRC" "$RES/icon.icns"
chmod 644 "$RES/icon.icns"

# ---------- 清隔离属性 ----------
echo "→ 清除隔离属性"
xattr -cr "$APP" 2>/dev/null || true

# ---------- 重签名 ----------
echo "→ ad-hoc 重签名（约 10-60 秒）"
codesign --force --deep --sign - "$APP" 2>&1 | sed 's/^/    /'

# ---------- 校验签名 ----------
echo "→ 校验签名"
if codesign -v "$APP" 2>/dev/null; then
  echo "    ✓ 签名有效"
else
  echo "    ✗ 签名校验失败！请运行 ./apply-icon.sh restore 还原"
  exit 1
fi

# ---------- 刷新图标缓存 ----------
echo "→ 刷新图标缓存"
touch "$APP"
killall Dock 2>/dev/null || true
/usr/bin/qlmanage -r cache >/dev/null 2>&1 || true

echo ""
echo "✓ 完成。Dock 图标应已更新。"
echo "  若仍显示旧图标: 把 Antigravity 从 Dock 移除再拖回来，或注销重登。"
echo "  还原官方原版: ./apply-icon.sh restore"
echo ""
