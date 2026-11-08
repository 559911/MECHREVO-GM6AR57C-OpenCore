#!/bin/bash
# 装完 WhateverXe Graphics pkg 之后必须运行本脚本。
#
# 做两件事：
#   1) 重打 Intel Metal 命令缓冲泄漏补丁（0x7ed87: 75 0d -> 90 90，然后整包重签）；
#      上游 0.4.1 仍未修，每装一次 pkg 都会把这段覆盖回去。
#   2) 把 AppleIntelTGLGraphicsVADriver.bundle 改名为 .disabled；
#      pkg 会把它装回启用状态，而本机核显 VA 路径在真实播放时会崩。
#
# 改动集中在 /Library/GPUBundles，执行前会备份，可用「6-还原用户态补丁.command」还原。
# 用法：双击本文件；或在终端里 bash 本文件。需要管理员密码。
# 适用：macOS 15.8.2 (24H232) + WhateverXe Graphics 0.4.1。
set -u

MTL_BUNDLE="/Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle"
MTL_BIN="$MTL_BUNDLE/Contents/MacOS/AppleIntelTGLGraphicsMTLDriver"
VAD_BUNDLE="/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle"
VAD_OFF="/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle.disabled"
STAMP=$(date +%Y%m%d-%H%M%S)
BK="/Users/Shared/wex-graphics-patch-backup-$STAMP"

echo "=============================================="
echo " 装完 Graphics pkg 后的两个用户态补丁"
echo "=============================================="
echo "备份目录：$BK"
echo

if [ ! -f "$MTL_BIN" ]; then
  echo "!! 未找到 $MTL_BIN"
  echo "   请先安装 WhateverXe Graphics 0.4.1 pkg 并重启一次，再运行本脚本。"
  echo "按回车关闭…"; read -r _; exit 1
fi

echo ">>> 需要管理员密码（只改 /Library/GPUBundles 下的这两个 bundle）"
sudo -v || { echo "取消。"; exit 1; }
sudo mkdir -p "$BK"

echo
echo "===== 1. 备份当前 MTLDriver ====="
sudo cp -p "$MTL_BIN" "$BK/AppleIntelTGLGraphicsMTLDriver.orig" || { echo "备份失败，中止。"; exit 1; }
echo "   已备份到 $BK/AppleIntelTGLGraphicsMTLDriver.orig"

echo
echo "===== 2. 命令缓冲泄漏补丁 ====="
if sudo python3 - "$MTL_BIN" << 'PY'
import sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())

# 版本指纹：-[MTLIGAccelCommandBuffer init] 里 new(0x12010) 的调用点。
# 0.3.2 / 0.4.0 / 0.4.1 三版此处完全一致；不匹配说明驱动变了，绝不盲改。
if d[0x7e9cb:0x7e9d5] != bytes.fromhex("bf10200100e839fe0100"):
    print("   !! 版本指纹不匹配，未做任何修改。请确认装的是 0.4.1，并查看上游是否已修复。")
    sys.exit(1)

at = 0x7ed87
cur = bytes(d[at:at + 2])
print("   目标字节:", cur.hex())
if cur == b'\x90\x90':
    print("   已是补丁版，跳过写入")
elif cur == b'\x75\x0d':
    d[at:at + 2] = b'\x90\x90'
    open(p, 'wb').write(d)
    print("   已写入 0x7ed87: 75 0d -> 90 90")
else:
    print("   !! 目标字节既不是 75 0d 也不是 90 90，未做任何修改。")
    sys.exit(1)
PY
then
  echo "   重签整包…"
  sudo codesign -f -s - --deep "$MTL_BUNDLE" >/dev/null 2>&1
  if codesign --verify --deep "$MTL_BUNDLE" >/dev/null 2>&1; then
    echo "   签名校验通过"
  else
    echo "   ⚠️ 签名校验未通过；若浏览器 GPU 进程起不来，运行「6-还原用户态补丁.command」"
  fi
else
  echo "   ⚠️ 泄漏补丁未应用（原因见上），继续处理 VADriver。"
fi

echo
echo "===== 3. 禁用 VADriver ====="
# pkg 带 <relocate/>：如果卷上还留着同名 CFBundleIdentifier 的 .disabled，
# 新载荷会被塞进它里面。所以先把旧的 .disabled 移走备份，而不是直接删除。
if [ -e "$VAD_OFF" ]; then
  sudo mv "$VAD_OFF" "$BK/AppleIntelTGLGraphicsVADriver.bundle.disabled" || { echo "   旧 .disabled 移走失败，中止。"; exit 1; }
  echo "   旧的 .disabled 已移到备份目录"
fi
if [ -d "$VAD_BUNDLE" ]; then
  sudo mv "$VAD_BUNDLE" "$VAD_OFF" || { echo "   改名失败，中止。"; exit 1; }
  echo "   已改名为 .disabled"
elif [ -d "$VAD_OFF" ]; then
  echo "   已是禁用状态（本次 pkg 未重新安装该 bundle）"
else
  echo "   ⚠️ 两个名字都没找到，请检查 pkg 是否安装完整："
  sudo find /Library/GPUBundles -maxdepth 3 -name 'AppleIntelTGLGraphicsVADriver.bundle*' -print
fi

echo
echo "===== 结果核对 ====="
python3 - "$MTL_BIN" << 'PY'
import sys, os
p = sys.argv[1]
d = open(p, 'rb').read()
b = d[0x7ed87:0x7ed89].hex()
print("   MTLDriver 0x7ed87 =", b, "（应为 9090）")
print("   VADriver.bundle 存在:", os.path.exists("/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle"))
print("   VADriver.bundle.disabled 存在:", os.path.exists("/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle.disabled"))
PY
echo
echo "备份：$BK"
echo "下一步：整机重启，然后双击「4-重启后自检.command」核对。"
echo "还原：双击「6-还原用户态补丁.command」。"
echo
echo "按回车关闭…"; read -r _
