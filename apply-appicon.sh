#!/bin/bash
# ============================================================
# Antigravity「系统级深浅双变体图标」安装 / 还原脚本
#
# 与 apply-icon.sh（单 icns 版）的区别：
#   本脚本装入 Icon Composer 格式的 Assets.car + CFBundleIconName，
#   走 macOS 26 新渲染路径 → 浅色模式白底、深色模式系统深色材质，
#   跟随系统外观自动切换（和 Gemini / VS Code 同机制）。
#
# 用法:
#   ./apply-appicon.sh install    # 安装双变体图标
#   ./apply-appicon.sh restore    # 还原官方原版（单 icns 路径）
#
# 说明:
#   - 会修改 Info.plist（CFBundleIconName / CFBundleIconFile）并新增
#     Resources/Assets.car 与 Resources/Antigravity.icns，首次运行自动备份
#   - 需要 macOS 26+；旧系统会自动 fallback 到 CFBundleIconFile
#   - 写 /Applications/*.app 内部属于 App Management 保护，需在「终端」运行
# ============================================================
set -euo pipefail

APP="/Applications/Antigravity.app"
RES="$APP/Contents/Resources"
PLIST="$APP/Contents/Info.plist"
PB="/usr/libexec/PlistBuddy"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_CAR="$HERE/compiled/Assets.car"
SRC_ICNS="$HERE/compiled/Antigravity.icns"
PLIST_BAK="$PLIST.antigravity-icon.bak"

ARG="${1:-}"

usage() {
  echo ""
  echo "用法: ./apply-appicon.sh install | restore"
  echo ""
  echo "  install   装入系统级深浅双变体图标（macOS 26+，浅色白底 / 深色系统材质）"
  echo "  restore   还原官方原版图标路径"
  echo ""
  echo "（只想换深色、不需要自动切换的话，用 ../apply-icon.sh G）"
  echo ""
  exit 0
}

[ -z "$ARG" ] && usage
[ "$ARG" != "install" ] && [ "$ARG" != "restore" ] && usage

# ---------- 提权 ----------
if [ "$(id -u)" -ne 0 ]; then
  echo "→ 需要写入 $APP 内部，正在提权（请输一次密码）..."
  exec /usr/bin/sudo -p "[sudo] 密码: " /bin/bash "$0" "$ARG"
fi

[ -f "$SRC_CAR" ] || { echo "✗ 缺少 $SRC_CAR"; exit 1; }
[ -f "$SRC_ICNS" ] || { echo "✗ 缺少 $SRC_ICNS"; exit 1; }

# ---------- 首次备份 Info.plist ----------
if [ ! -f "$PLIST_BAK" ]; then
  echo "→ 备份 Info.plist → Info.plist.antigravity-icon.bak"
  cp "$PLIST" "$PLIST_BAK"
fi

if [ "$ARG" = "install" ]; then
  echo "→ 装入 Assets.car（分层图标，含深浅双外观）"
  cp "$SRC_CAR" "$RES/Assets.car"

  echo "→ 装入 Antigravity.icns（合成 fallback，供旧路径引用）"
  cp "$SRC_ICNS" "$RES/Antigravity.icns"

  echo "→ 更新 Info.plist：CFBundleIconName / CFBundleIconFile → Antigravity"
  "$PB" -c "Set :CFBundleIconFile Antigravity" "$PLIST" 2>/dev/null \
    || "$PB" -c "Add :CFBundleIconFile string Antigravity" "$PLIST"
  "$PB" -c "Set :CFBundleIconName Antigravity" "$PLIST" 2>/dev/null \
    || "$PB" -c "Add :CFBundleIconName string Antigravity" "$PLIST"
else
  echo "→ 还原 Info.plist（从备份）"
  cp "$PLIST_BAK" "$PLIST"

  echo "→ 移除 Assets.car / Antigravity.icns"
  rm -f "$RES/Assets.car" "$RES/Antigravity.icns"

  echo "→ 恢复官方原版 icon.icns（如有备份）"
  [ -f "$RES/icon.icns.orig" ] && cp "$RES/icon.icns.orig" "$RES/icon.icns"
fi

# ---------- 清隔离 + 重签 + 刷新 ----------
echo "→ 清除隔离属性"
xattr -cr "$APP" 2>/dev/null || true

echo "→ ad-hoc 重签名（约 10-60 秒）"
codesign --force --deep --sign - "$APP" 2>&1 | sed 's/^/    /'

echo "→ 校验签名"
if codesign -v "$APP" 2>/dev/null; then
  echo "    ✓ 签名有效"
else
  echo "    ✗ 签名校验失败！请运行 ./apply-appicon.sh restore 还原"
  exit 1
fi

echo "→ 刷新图标缓存"
touch "$APP"
killall Dock 2>/dev/null || true
/usr/bin/qlmanage -r cache >/dev/null 2>&1 || true

echo ""
echo "✓ 完成。切换系统深浅模式试试 —— Dock 图标应自动跟随。"
echo "  若 Dock 显示旧图标: 把 Antigravity 从 Dock 移除再拖回，或注销重登。"
echo "  还原: ./apply-appicon.sh restore"
echo ""
