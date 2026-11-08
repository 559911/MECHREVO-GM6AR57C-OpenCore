#!/bin/bash
# 熄屏唤醒黑屏回归测试（可多轮）。
#
# 这套配置靠「两补丁 + -nodisplaysleepDC6」把熄屏后黑屏绕开，必须用长熄屏实测，
# 不能只看 IORegistry 标志。历史必败区间是连续熄屏 85 / 122 / 131 秒。
#
# 用法：双击（默认 120 210 120 三轮），或 bash 5-熄屏唤醒回归.command 120 210
# 判据：连续熄屏 >=85 秒、TrainingError=0、唤醒后 IODisplayWrangler=4、
#       面板供电回 02、WindowServer 活着、零新增 panic；屏幕亮起仍需肉眼确认。
#
# 取证要点：唤醒后约 30 秒系统会自动二次熄屏，所以取证窗口必须 <=15 秒，
# 并用 caffeinate -u -t 22 撑住亮屏；连续多轮时屏本来就是灭的，
# 时长要「取本轮 exit，往前配最近一条 enter」。
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REC="$HERE/记录"
mkdir -p "$REC"
RUN=$(date +%Y%m%d-%H%M%S)
SUM="$REC/唤醒回归-$RUN.log"
ROUNDS=("$@")
[ ${#ROUNDS[@]} -eq 0 ] && ROUNDS=(120 210 120)
WAIT_AFTER_WAKE=15
GAP=10
BOOT=$(sysctl -n kern.boottime | sed -E 's/.*\{ sec = ([0-9]+),.*/\1/')

wex() { ioreg -n Root -l -w0 2>/dev/null | /usr/bin/grep -m1 "\"$1\"" | sed 's/^[[:space:]]*//'; }
panic_count() { find /Library/Logs/DiagnosticReports -name "*.panic" -newermt "@$BOOT" 2>/dev/null | wc -l | tr -d ' '; }

# 输出：连续无媒体秒数 TrainingError 数
metrics() {
python3 - "$1" "$2" << 'PY'
import sys, datetime, pathlib
lo, hi = sys.argv[1], sys.argv[2]
p = pathlib.Path("/var/log/displaypolicy/displaypolicyd.0:2:0.log")
f = lambda s: datetime.datetime.strptime(s[:26], "%Y-%m-%d %H:%M:%S.%f")
last_ent = None; te = 0; dz = -1
if not p.exists():
    print(dz, te); sys.exit(0)
for line in p.read_text(errors='ignore').splitlines():
    if "No_Media_Mode enter" in line:
        last_ent = f(line); te = 0
    elif "No_Media_Mode exit" in line:
        ts = line[:19]
        if lo <= ts <= hi and last_ent is not None:
            dz = int((f(line) - last_ent).total_seconds()); break
    elif last_ent is not None and "TrainingError" in line:
        te += 1
print(dz, te)
PY
}

{
echo "======== 熄屏唤醒回归 $RUN ========"
echo "系统：$(sw_vers -productVersion)（$(sw_vers -buildVersion)）"
echo "Graphics：$(pkgutil --pkg-info org.b00t0x.WhateverXe.Sequoia 2>/dev/null | awk '/^version/{print $2}')"
echo "boot-args：$(nvram boot-args 2>/dev/null | sed 's/^boot-args[[:space:]]*//')"
echo "轮次：${ROUNDS[*]} 秒"
echo
echo "--- 前置判据 ---"
for k in TGLRecoverySinglePassRequested TGLRecoverySinglePassReady WhateverXePanelPowerHooked TGLMMIOStrongUCRouted; do
  echo "  $(wex "$k")"
done
case "$(nvram boot-args 2>/dev/null)" in *-nodisplaysleepDC6*) echo "  ✅ -nodisplaysleepDC6 在";; *) echo "  ❌ -nodisplaysleepDC6 不在，本轮无意义";; esac
if ioreg -n Root -l -w0 2>/dev/null | /usr/bin/grep -q TGLWEXDozeDCGuardReady; then
  echo "  ⚠️ 检测到 DC 守卫属性 —— 装成旧三补丁版了"
else
  echo "  ✅ DC 守卫两条属性不存在（符合两补丁版）"
fi
PANIC0=$(panic_count)
echo "  本次开机后 panic 数：${PANIC0}"
echo

PASS=0; FAIL=0; INVALID=0; ABORT=0
i=0
for d in "${ROUNDS[@]}"; do
  i=$((i + 1))
  echo "================ 第 ${i} 轮 / 共 ${#ROUNDS[@]} 轮 · 计划熄屏 ${d}s ================"
  T0=$(date '+%Y-%m-%d %H:%M:%S')
  E0=$(date +%s)
  echo "  熄屏…（$(date +%H:%M:%S)）"
  pmset displaysleepnow
  sleep "$d"
  DSP_BEFORE=$(pmset -g powerstate IODisplayWrangler 2>/dev/null | awk '/IODisplayWrangler/{print $2}')
  E1=$(date +%s)
  WALL=$((E1 - E0))
  caffeinate -u -t 2 >/dev/null 2>&1
  caffeinate -u -t 22 >/dev/null 2>&1 &
  echo "  已发唤醒（$(date +%H:%M:%S)），撑住亮屏，${WAIT_AFTER_WAKE}s 取证"
  sleep 3
  DSP=$(pmset -g powerstate IODisplayWrangler 2>/dev/null | awk '/IODisplayWrangler/{print $2}')
  PPC=$(wex WhateverXePanelPowerCall)
  echo "  唤醒前显示电源状态：${DSP_BEFORE}（1＝熄灭，4＝已点亮）"
  echo "  唤醒后 3s 显示电源状态：${DSP}（4＝USEABLE／已点亮）"
  echo "  唤醒后 3s 面板供电：${PPC}"
  sleep $((WAIT_AFTER_WAKE - 3))
  T1=$(date '+%Y-%m-%d %H:%M:%S')
  read -r DZ TE < <(metrics "$T0" "$T1")
  DZ=${DZ:--1}; TE=${TE:-0}
  WS=$(pgrep -x WindowServer >/dev/null 2>&1 && echo 活着 || echo 不在)
  echo
  echo "  --- 本轮结果 ---"
  echo "  脚本墙钟熄屏：${WALL} 秒"
  echo "  实际连续熄屏：${DZ} 秒（往前配最近一条 enter）"
  echo "  本轮 TrainingError：${TE}"
  echo "  WindowServer：${WS}"
  echo "  -- displaypolicyd 关键行 --"
  python3 - "$T0" "$T1" << 'PY'
import sys, pathlib
lo, hi = sys.argv[1], sys.argv[2]
p = pathlib.Path("/var/log/displaypolicy/displaypolicyd.0:2:0.log")
if p.exists():
    for line in p.read_text(errors='ignore').splitlines():
        ts = line[:19]
        if lo <= ts <= hi and any(k in line for k in ("No_Media_Mode", "TrainingError", "LinkUpdate")):
            print("    " + line[:132])
PY
  echo
  if [ "$DSP_BEFORE" = "4" ]; then
    echo "  本轮结论：无效 —— 唤醒前屏幕已经是亮的，中途被意外唤醒过"; INVALID=$((INVALID + 1))
  elif [ "$DZ" -lt 5 ] 2>/dev/null; then
    echo "  本轮结论：无效 —— 连续熄屏仅 ${DZ}s，没抓到成对的 enter/exit"; INVALID=$((INVALID + 1))
  elif [ "$TE" -ne 0 ] 2>/dev/null; then
    echo "  本轮结论：❌ 失败（出现 TrainingError），立即回退"; FAIL=$((FAIL + 1)); ABORT=1
  elif [ "$WS" != "活着" ]; then
    echo "  本轮结论：❌ 失败（WindowServer 没起来）"; FAIL=$((FAIL + 1)); ABORT=1
  elif [ "$DSP" != "4" ]; then
    echo "  本轮结论：❌ 失败（唤醒后显示器状态 ${DSP}，疑似黑屏）"; FAIL=$((FAIL + 1)); ABORT=1
  elif [ "$DZ" -ge 85 ] 2>/dev/null; then
    echo "  本轮结论：✅ 通过（连续熄屏 ${DZ}s，零 TrainingError，屏已点亮）"; PASS=$((PASS + 1))
  else
    echo "  本轮结论：⚠️ 熄屏 ${DZ}s 偏短（未到 85s 必败区间），有参考价值但不算定论"; INVALID=$((INVALID + 1))
  fi
  case "$PPC" in *"<02"*) echo "  面板上电已走到 P2 钩子（state=2）";; *) echo "  ⚠️ 未见 state=2 上电调用，需人工确认屏幕";; esac
  echo
  [ "$ABORT" -eq 1 ] && break
  [ "$i" -lt "${#ROUNDS[@]}" ] && sleep "$GAP"
done

PANIC1=$(panic_count)
echo "================ 收尾 ================"
echo "  panic：开机后 ${PANIC0} → 现在 ${PANIC1}"
for k in TGLRecoverySinglePassRequested TGLRecoverySinglePassReady WhateverXePanelPowerHooked TGLMMIOStrongUCRouted; do
  echo "  $(wex "$k")"
done
echo "  传感器：$(sysctl -n kern.nvgputemp 2>/dev/null) ℃ / $(sysctl -n kern.nvgpupower 2>/dev/null) mW / $(sysctl -n kern.nvgpustate 2>/dev/null)"
echo
echo "================ 总结 ================"
echo "  计划 ${#ROUNDS[@]} 轮，通过 ${PASS} 轮，失败 ${FAIL} 轮，无效 ${INVALID} 轮"
if [ "$FAIL" -eq 0 ] && [ "$INVALID" -eq 0 ] && [ "$PASS" -eq "${#ROUNDS[@]}" ] && [ "$PANIC1" -eq "$PANIC0" ]; then
  echo "  ✅ 多轮全部通过：零 TrainingError、零新增 panic、唤醒后状态 4 → 配置可用"
else
  echo "  ⚠️ 存在失败/无效轮次或新增 panic → 不要继续用，按 README 回退"
fi
echo "  ⚠️ 客观判据不能替代肉眼：屏幕是否真的亮起仍需你确认"
echo "  记录：$SUM"
} 2>&1 | tee "$SUM"

echo
echo "按回车关闭…"; read -r _
