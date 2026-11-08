#!/bin/bash
# 重启后自检：逐项核对这套配置是否真的生效。
#
# 判据全部来自运行时 IORegistry / sysctl / 文件字节，不看源码里有没有函数。
# 用法：双击，或 bash 4-重启后自检.command [实际引导介质上的 config.plist 路径]
#   不带参数时核对发布包内的 EFI/OC/config.plist（内容与你要拷进引导介质的一致）。
# 只读，不需要管理员密码。
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
CFG="${1:-$ROOT/EFI/OC/config.plist}"
SMCREAD="$ROOT/工具/smcread"
PASS=0; FAIL=0; WARN=0
ok()   { echo "   ✅ $1"; PASS=$((PASS + 1)); }
bad()  { echo "   ❌ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "   ⚠️  $1"; WARN=$((WARN + 1)); }
wex()  { ioreg -n Root -l -w0 2>/dev/null | /usr/bin/grep -m1 "\"$1\"" | sed 's/^[[:space:]|]*//'; }
has()  { ioreg -n Root -l -w0 2>/dev/null | /usr/bin/grep -q "$1"; }

echo "=============================================="
echo " 重启后自检 · MECHREVO GM6AR57C / v14"
echo "=============================================="
echo "时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo

echo "===== 1. 版本（补丁绑死 15.8.2 / 24H232）====="
VER=$(sw_vers -productVersion); BUILD=$(sw_vers -buildVersion)
echo "   macOS ${VER}（${BUILD}）"
[ "$VER" = "15.8.2" ] && [ "$BUILD" = "24H232" ] && ok "系统版本匹配" || warn "系统版本与验证环境不同，所有补丁需重新验证"
echo "   Graphics pkg: $(pkgutil --pkg-info org.b00t0x.WhateverXe.Sequoia 2>/dev/null | awk '/^version/{print $2}' || echo 未安装)"
echo "   NVRM:        $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' /Library/Extensions/NVRM.kext/Contents/Info.plist 2>/dev/null || echo 未安装)"

echo
echo "===== 2. config 与本次开机的 boot-args ====="
if [ -f "$CFG" ] && plutil -lint "$CFG" >/dev/null 2>&1; then
  CFGBA=$(/usr/libexec/PlistBuddy -c "Print :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args" "$CFG" 2>/dev/null)
  echo "   config boot-args：$CFGBA"
  case "$CFGBA" in *-nodisplaysleepDC6*) ok "config 含 -nodisplaysleepDC6";; *) bad "config 缺 -nodisplaysleepDC6（DC6 会按原生方式武装）";; esac
else
  bad "config.plist 不存在或格式错误：$CFG"
fi
NVBA=$(nvram boot-args 2>/dev/null | sed 's/^boot-args[[:space:]]*//')
echo "   本次开机实际：$NVBA"
case "$NVBA" in *-nodisplaysleepDC6*) ok "本次开机含 -nodisplaysleepDC6";; *) bad "本次开机没有该参数（还在跑旧 EFI，或没重启）";; esac

echo
echo "===== 3. EFI 里的两个自制 kext ====="
EFIROOT=$(cd "$(dirname "$CFG")" && pwd)
WX="$EFIROOT/Kexts/WhateverXe.kext/Contents/MacOS/WhateverXe"
if [ -f "$WX" ]; then
  H=$(shasum -a 256 "$WX" | cut -c1-8)
  echo "   WhateverXe 二进制：$H"
  [ "$H" = "5dbfbbbf" ] && ok "是 0.8.0 两补丁版" || bad "不是两补丁版（5dbfbbbf），请勿继续"
else
  warn "未在 $EFIROOT 下找到 WhateverXe.kext，跳过"
fi
SIP="$EFIROOT/Kexts/SMCNvidiaGPU.kext/Contents/Info.plist"
if [ -f "$SIP" ]; then
  SV=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SIP" 2>/dev/null)
else
  SV="未找到"
fi
echo "   SMCNvidiaGPU：$SV"
[ "$SV" = "1.8.5" ] && ok "传感器插件版本 1.8.5" || warn "版本不是 1.8.5，旧版在 NVRM 2.7.2 上传感器会全空"

echo
echo "===== 4. 内核补丁标志（必须看运行时）====="
for k in TGLRecoverySinglePassRequested TGLRecoverySinglePassReady WhateverXePanelPowerHooked TGLMMIOStrongUCRouted TGLAcceleratorAdmissionReady ADLSPanelPWMReady; do
  LINE=$(wex "$k")
  echo "   $LINE"
  case "$LINE" in *"= Yes"*) ok "$k = Yes";; *) bad "$k 不是 Yes";; esac
done
echo "   —— 以下两条【应当不存在】，出现即装成旧的三补丁版 ——"
if has TGLWEXDozeDCGuardReady || has TGLWEXFBStateRouted; then
  bad "检测到 DC 守卫属性，装错版本"
else
  ok "TGLWEXDozeDCGuardReady / TGLWEXFBStateRouted 不存在"
fi
if [ "$(wex TGLRecoverySinglePassRequested)" != "" ] && [ "$(wex TGLRecoverySinglePassReady)" != "" ]; then
  case "$(wex TGLRecoverySinglePassRequested)" in *Yes*) case "$(wex TGLRecoverySinglePassReady)" in *No*) bad "Requested=Yes / Ready=No：donor 逐字节校验没过，立即回退";; esac;; esac
fi

echo
echo "===== 5. 内屏亮度（P1 生效时会是中间档）====="
ioreg -r -c AppleBacklightDisplay -l -w0 2>/dev/null | /usr/bin/grep -E '"(AppleBrightness|AppleMaxBrightness|IODisplayParameters)"' | head -6 | sed 's/^/   /'
echo "   请人工确认：亮度滑块可连续调节，不是只有 0 / 满亮两档"
echo "   面板供电调用记录：$(wex WhateverXePanelPowerCall)"

echo
echo "===== 6. 独显传感器（1.8.5 绑定成功终态）====="
ST=$(sysctl -n kern.nvgpustate 2>/dev/null || echo n/a)
DIS=$(sysctl -n kern.nvgpudiscover 2>/dev/null || echo n/a)
TEMP=$(sysctl -n kern.nvgputemp 2>/dev/null || echo 0)
PWR=$(sysctl -n kern.nvgpupower 2>/dev/null || echo 0)
echo "   nvgpustate：$ST"
echo "   nvgpudiscover：$DIS"
echo "   GPU 温度：${TEMP} ℃   功耗：${PWR} mW（单位毫瓦，约 20500 = 20.5 W）"
case "$DIS" in *used=anchor*) ok "已定位 NVRM 锚点";; *) bad "未定位 NVRM（传感器会是空的）";; esac
case "$ST" in *"polling mask"*) ok "RUSD 轮询已开启（绑定成功终态不是 bound NVRM）";; *"waiting for NVRM"*) bad "未绑定 NVRM";; *) warn "状态非典型：$ST";; esac
[ "${TEMP:-0}" -gt 0 ] 2>/dev/null && ok "温度非 0" || bad "温度为 0，传感器无效"
if [ -x "$SMCREAD" ]; then
  echo "   SMC TG0D：$("$SMCREAD" k TG0D 2>/dev/null | tail -1)"
else
  echo "   SMC TG0D：（发布包内工具/smcread 不可执行，跳过）"
fi
echo "   驱动侧温度：$(ioreg -r -c NVAccel -d 1 2>/dev/null | /usr/bin/grep -o '"Temperature(C)"=[0-9]*' | head -1)"

echo
echo "===== 7. 用户态补丁 ====="
MTL=/Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle/Contents/MacOS/AppleIntelTGLGraphicsMTLDriver
if [ -f "$MTL" ]; then
  B=$(python3 -c "print(open('$MTL','rb').read()[0x7ed87:0x7ed89].hex())" 2>/dev/null)
  echo "   MTLDriver 0x7ed87 = $B"
  [ "$B" = "9090" ] && ok "命令缓冲泄漏补丁已应用" || bad "未打补丁（装完 Graphics pkg 要重打）"
else
  bad "未找到 MTLDriver，Graphics pkg 可能没装"
fi
if [ -d /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle.disabled ] && [ ! -d /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle ]; then
  ok "VADriver 保持 .disabled"
else
  bad "VADriver 不是禁用状态（真实播放会崩）"
fi

echo
echo "===== 8. 显示 / 硬解 / panic ====="
system_profiler SPDisplaysDataType 2>/dev/null | /usr/bin/grep -E "Resolution|UI Looks like|Metal" | sed 's/^/   /'
BOOT=$(sysctl -n kern.boottime | sed -E 's/.*\{ sec = ([0-9]+),.*/\1/')
echo "   本次开机新增 panic：$(find /Library/Logs/DiagnosticReports -name '*.panic' -newermt "@$BOOT" 2>/dev/null | wc -l | tr -d ' ')"
echo "   （系统睡眠应为关闭：$(pmset -g custom 2>/dev/null | /usr/bin/grep -m1 ' sleep ' | sed 's/^ *//')）"

echo
echo "=============================================="
echo " 结果：通过 $PASS 项 / 失败 $FAIL 项 / 提示 $WARN 项"
if [ "$FAIL" -eq 0 ]; then
  echo " ✅ 运行时判据全部通过。再做一次熄屏唤醒回归（5 号脚本）并亲眼确认屏幕亮起。"
else
  echo " ❌ 有失败项，先按 README「故障判据速查」处理，必要时回退到安装前状态。"
fi
echo "=============================================="
echo
echo "按回车关闭…"; read -r _
