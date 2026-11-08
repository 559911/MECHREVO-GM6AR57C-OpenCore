#!/bin/bash
# 安装内屏 1440x900 HiDPI 显示 override（系统侧补丁，与 EFI 无关）。
#
# 本机面板 2560x1600、EDID 只有一条 2560x1600@60 的 DTD，系统默认 HiDPI 上限是
# 1280x800。这份 override 以 flags=9 + 0x00A00000 声明 2880x1800 缩放模式，
# 由 Intel pipe scaler 缩小 1.125 倍输出，得到「看起来像 1440x900」的桌面。
#
# 只在开机时被读取：装完必须整机重启，注销重登 / 重启 WindowServer 都无效。
# 适用面板标识：DisplayVendorID-9e5 / DisplayProductID-a1f。
# 用法：双击本文件，需要管理员密码；还原用「3-还原HiDPI覆盖.command」。
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC="$ROOT/工具/内屏HiDPI-1440x900/DisplayProductID-a1f"
DST_DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-9e5"
DST="$DST_DIR/DisplayProductID-a1f"
STAMP=$(date +%Y%m%d-%H%M%S)
BK="/Users/Shared/HiDPI-override-backup-$STAMP"

echo "=============================================="
echo " 内屏 1440x900 HiDPI 覆盖安装"
echo "=============================================="
echo "来源：$SRC"
echo "目标：$DST"
echo

if [ ! -f "$SRC" ]; then
  echo "!! 找不到 $SRC"
  echo "   请确认发布包目录结构完整（工具/内屏HiDPI-1440x900/）。"
  echo "按回车关闭…"; read -r _; exit 1
fi
if [ ! -d "$DST_DIR" ]; then
  echo "!! 目标目录不存在：$DST_DIR"
  echo "   说明当前面板标识不是 09e5:0a1f，本 override 不适用，已中止。"
  echo "按回车关闭…"; read -r _; exit 1
fi

echo ">>> 需要管理员密码（备份 + 写入）"
sudo -v || { echo "取消。"; exit 1; }
sudo mkdir -p "$BK"
sudo cp -R "$DST_DIR/." "$BK/" || { echo "备份失败，已中止。"; exit 1; }
echo "已备份到：$BK"

sudo cp "$SRC" "$DST" || { echo "写入失败，已中止。"; exit 1; }
sudo chown root:wheel "$DST"
sudo chmod 644 "$DST"
sudo touch "$DST_DIR"

echo
echo "===== 校验 ====="
plutil -lint "$DST"
python3 - "$DST" << 'PY'
import plistlib, sys, struct
p = plistlib.load(open(sys.argv[1], 'rb'))
n = p.get("scale-resolutions", [])
print("   EDID: %d 字节   条目数: %d" % (len(p.get("IODisplayEDID", b"")), len(n)))
hit = [e for e in n if len(e) == 16 and struct.unpack(">I", bytes(e)[0:4])[0] == 2880]
print("   2880x1800 缩放条目:", "存在" if hit else "缺失")
if hit:
    e = bytes(hit[0])
    print("   flags=%d  extra=0x%08X" % (struct.unpack(">I", e[8:12])[0], struct.unpack(">I", e[12:16])[0]))
PY

echo
echo "----------------------------------------------"
echo "重要：这份配置只在【开机】时读取，必须整机重启。"
echo "  注销重登、重启 WindowServer 均无效（已实测）。"
echo "----------------------------------------------"
echo "输入 r 回车可立即重启；直接回车则稍后自行重启。"
read -r ans
if [ "$ans" = "r" ] || [ "$ans" = "R" ]; then
  sudo shutdown -r now
else
  echo "请记得手动重启：苹果菜单 → 重新启动。"
  echo "按回车关闭…"; read -r _
fi
