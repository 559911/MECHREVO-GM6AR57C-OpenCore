#!/bin/bash
# 撤销「1-装完Graphics包后补丁.command」做的两处改动：
#   1) 用备份恢复 MTLDriver 原文件并整包重签（去掉 0x7ed87 的 90 90）；
#   2) 把 AppleIntelTGLGraphicsVADriver.bundle.disabled 改回 .bundle。
#
# 用于排查、或准备升级 WhateverXe Graphics pkg 之前。改完要整机重启。
# 用法：双击本文件，需要管理员密码。
set -u

MTL_BUNDLE="/Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle"
MTL_BIN="$MTL_BUNDLE/Contents/MacOS/AppleIntelTGLGraphicsMTLDriver"
VAD_BUNDLE="/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle"
VAD_OFF="/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle.disabled"
STAMP=$(date +%Y%m%d-%H%M%S)
BK="/Users/Shared/wex-graphics-restore-$STAMP"

echo "=============================================="
echo " 还原用户态补丁（撤销 1 号脚本）"
echo "=============================================="

ORIG=$(ls -t /Users/Shared/wex-graphics-patch-backup-*/AppleIntelTGLGraphicsMTLDriver.orig 2>/dev/null | head -1)
if [ -z "$ORIG" ] || [ ! -f "$ORIG" ]; then
  echo "!! 找不到 1 号脚本留下的 MTLDriver 备份，无法自动还原二进制。"
  echo "   可重新安装一次 WhateverXe Graphics 0.4.1 pkg，它会覆盖回未打补丁的原文件。"
  echo "按回车关闭…"; read -r _; exit 1
fi
echo "使用备份：$ORIG"

echo ">>> 需要管理员密码"
sudo -v || { echo "取消。"; exit 1; }
sudo mkdir -p "$BK"

echo
echo "===== 1. 恢复 MTLDriver ====="
sudo cp -p "$MTL_BIN" "$BK/AppleIntelTGLGraphicsMTLDriver.patched" 2>/dev/null || true
sudo cp -p "$ORIG" "$MTL_BIN" || { echo "恢复失败，中止。"; exit 1; }
sudo codesign -f -s - --deep "$MTL_BUNDLE" >/dev/null 2>&1
python3 - "$MTL_BIN" << 'PY'
import sys
d = open(sys.argv[1], 'rb').read()
print("   0x7ed87 =", d[0x7ed87:0x7ed89].hex(), "（还原后应为 750d）")
PY
codesign --verify --deep "$MTL_BUNDLE" >/dev/null 2>&1 && echo "   签名校验通过" || echo "   ⚠️ 签名校验未通过"

echo
echo "===== 2. 恢复 VADriver ====="
if [ -d "$VAD_BUNDLE" ]; then
  sudo mv "$VAD_BUNDLE" "$BK/AppleIntelTGLGraphicsVADriver.bundle" || { echo "   已有 .bundle 移走失败，中止。"; exit 1; }
  echo "   已把现有 .bundle 移到备份目录，避免改名时嵌套"
fi
if [ -d "$VAD_OFF" ]; then
  sudo mv "$VAD_OFF" "$VAD_BUNDLE" || { echo "   恢复失败，中止。"; exit 1; }
  echo "   已改回 .bundle（核显 VA 路径重新启用）"
else
  echo "   没有找到 .disabled，可能本来就没禁用"
fi

echo
echo "备份：$BK"
echo "已还原。请整机重启。注意：还原后核显 VA 路径重新启用，"
echo "真实播放视频可能触发像素转换崩溃，长时间浏览也可能重现命令缓冲泄漏。"
echo
echo "按回车关闭…"; read -r _
