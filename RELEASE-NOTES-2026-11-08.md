# v14 · 2026-11-08 · 两补丁 + 传感器 1.8.5

**MECHREVO GM6AR57C / i7-12800HX / RTX 4070 Laptop / macOS 15.8.2（24H232）· Hybrid MUX**

## 本版内容

| 组件 | v11（上一发布版） | **v14（本版）** |
|---|---|---|
| WhateverXe（EFI 内 kext） | 0.6.1 / 0.7.x + 本地补丁 | **0.8.0 + 2 处本地补丁**（`5dbfbbbf…`） |
| 本地补丁数 | 3 处 + 恢复补丁 | **2 处**（P3 由 `-nodisplaysleepDC6` 替代） |
| WhateverXe Graphics（系统侧 pkg） | 0.3.2 / 0.4.0 | **0.4.1** |
| NullMoth NVRM | 2.6.5 | **2.7.2** |
| SMCNvidiaGPU | 1.3.2 / 1.6 | **1.8.5**（按上游源码原样编译，绑定表现场生成） |
| 内屏 HiDPI | 1280×800 | **1440×900**（`/Library/Displays` override） |

相对 v11 的主要改动：

1. **本地补丁从 3 处减到 2 处**：Doze 期间不武装 DC6/DC9 的钩子删除，
   改用苹果 `AppleIntelFramebufferController` 自带的 `-nodisplaysleepDC6`；
   原生流程其余部分照跑，改动面更小。
2. **背光与唤醒两处补丁保留**（上游 0.8.0 逐条核对仍未修）：
   ADL-S 去 FUSE bit24 门禁、面板供电 non-power-on 状态 no-op。
3. **传感器升到 1.8.5**：NVRM 2.7.2 起改用 `nvDisplayPointers` 取地址，
   1.7 及更早 kext 会定位不到驱动、传感器全空。1.8.5 未加任何本机补丁。
4. **Graphics 升到 0.4.1**：只改 `AppleIntelTGLCompat`（放宽内核 build 匹配），
   三个图形主文件逐字节未变，MTL 泄漏补丁偏移不漂。
5. **系统侧两个用户态补丁脚本化**：MTL 命令缓冲泄漏 `0x7ed87 75 0d → 90 90` + 整包重签、
   VADriver 保持 `.disabled`；每次装完 Graphics pkg 一键重打。
6. **发布包新增**：重启后自检、熄屏唤醒回归、HiDPI 安装 / 还原、用户态补丁还原共 6 个一键脚本，
   以及两补丁构建说明、boot-args 逐项归属说明、校验值。

## 验证结果

- 2026-11-08 本次开机累计 **8 轮熄屏唤醒**；正式判据 2 轮连续熄屏 **193 / 223 秒**，
  零 `TrainingError`、唤醒后 `IODisplayWrangler=4`、面板供电回 `02`、零新增 panic。
- 运行时判据：五项 WEX 标志 + `ADLSPanelPWMReady` 全 Yes，
  `TGLWEXDozeDCGuardReady` / `TGLWEXFBStateRouted` 不存在（符合两补丁版）。
- 传感器：`used=anchor`、`polling mask 0xff / 500 ms`、温度与驱动侧一致；`kern.nvgpupower` 约 20500 mW。
- 硬解：H.264 1080p ≈168 fps、HEVC 4K ≈118–132 fps，零崩溃，走独显 NVDEC。
- 最近 1 小时内核日志 panic / TrainingError / link training / GPU reset 关键字命中 0。

## 已知限制

睡眠永久关闭；独显无头常驻约 20.4 W 且不能动态调频；内屏 165 Hz 用不上（EDID 限制）；
核显 VA 硬解主动禁用、NVENC 硬编码关闭；风扇转速无 SMC 接口；
App Store 视频 / FairPlay / 外接 DP 重连为上游已知问题。详见 README 第 1、2 节。

## 安装

**只拷 EFI 不会有图形加速。** 请严格按 `README.md` 第 3 节的 15 个步骤操作：
生成三码 → 首次引导 → 装 1401 / NVRM 2.7.2 → 装 Graphics 0.4.1 → 跑 `脚本/1`
→ 核对两补丁 kext 与传感器 → 装 HiDPI override → 跑 `脚本/4` / `脚本/5` 验证。

> 补丁绑死 macOS 15.8.2（24H232）、`AppleIntelTGLGraphics 16.0.0`、NVRM 2.7.2。
> 换系统或换驱动版本都要重新验证；升级 Graphics pkg 后必须重跑 `脚本/1`。

## 三码

`EFI/OC/config.plist` 的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 均为占位值，
**必须自行生成并填入**，机型保持 `MacBookPro16,2`。
