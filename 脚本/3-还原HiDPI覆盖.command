#!/bin/bash
# 还原内屏显示 override 到安装前状态（撤销 1440x900 HiDPI）。
#
# 还原来源优先级：
#   1) 发布包内自带的原版备份 工具/内屏HiDPI-1440x900/原版备份-DisplayVendorID-9e5/
#   2) 安装脚本在 /Users/Shared/HiDPI-override-backup-* 留下的现场备份（取最新一份）
# 改完同样必须整机重启才生效。
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
PKG_BAK="$ROOT/工具/内屏HiDPI-1440x900/原版备份-DisplayVendorID-9e5/DisplayProductID-a1f"
DST_DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-9e5"
DST="$DST_DIR/DisplayProductID-a1f"

echo "=============================================="
echo " 还原内屏显示 override"
echo "=============================================="

SRC=""
if [ -f "$PKG_BAK" ]; then
  SRC="$PKG_BAK"
  echo "使用发布包内原版备份：$SRC"
else
  latest=$(ls -td /Users/Shared/HiDPI-override-backup-*/DisplayProductID-a1f 2>/dev/null | head -1)
  if [ -n "$latest" ] && [ -f "$latest" ]; then
    SRC="$latest"
    echo "使用安装时的现场备份：$SRC"
  fi
fi

if [ -z "$SRC" ]; then
  echo "!! 找不到任何原版备份，未做改动。"
  echo "   如果只想去掉 1440x900，可在「系统设置 → 显示器」里选回 1280x800 档位。"
  echo "按回车关闭…"; read -r _; exit 1
fi
if [ ! -d "$DST_DIR" ]; then
  echo "!! 目标目录不存在：$DST_DIR，未做改动。"
  echo "按回车关闭…"; read -r _; exit 1
fi

echo ">>> 需要管理员密码"
sudo -v || { echo "取消。"; exit 1; }
sudo cp "$SRC" "$DST" || { echo "还原失败。"; exit 1; }
sudo chown root:wheel "$DST"
sudo chmod 644 "$DST"
sudo touch "$DST_DIR"
plutil -lint "$DST"

echo
echo "已还原。必须整机重启才会生效（注销重登无效）。"
echo "按回车关闭…"; read -r _
