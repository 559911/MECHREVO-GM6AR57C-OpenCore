# MECHREVO GM6AR57C · OpenCore EFI（混合模式 · 核显加速可用）

**i7-12800HX · RTX 4070 Laptop · Intel UHD（ADL-HX）· macOS Sequoia 15.8.2**

> 这份 EFI 让内屏走**核显**、独显同时可用（BIOS 设为混合模式 / MUX Hybrid）。
> 内屏 2560×1600 HiDPI 正常、亮度可调；独显 Metal 3 正常。
> **核显加速已放行**（控制中心、通知中心、小部件均正常），
> **第三方播放器硬解可用**（走 NVIDIA 解码，详见第 4.5 节）。
> 本版对应 `EFI-版本/08`，相比 07 版仅核显插件（WhateverXe.kext）换为带 15.8.2 准入修复的自编译版。

---

## 1. 硬件

| 部件 | 型号 / 标识 |
|---|---|
| 机型 | MECHREVO GM6AR57C（同方 GM6AR57C 模具，16 英寸） |
| CPU | Intel Core i7-12800HX（8P+8E / 24 线程） |
| 核显 | Intel UHD Graphics，`8086:4688`（Alder Lake-HX，32EU） |
| 独显 | NVIDIA RTX 4070 Laptop，`10de:2820`，8GB |
| 内存 | 16GB DDR5-4800 板载 |
| 硬盘 | KINGSTON OM8PGP41024N-A0 1TB NVMe |
| 屏幕 | 2560×1600 @165Hz，BOE（EDID `09e5:0a1f`），eDP |
| 声卡 | Conexant SN6140（`14f1:1f87`） |
| 无线 / 蓝牙 | Intel AX201 CNVi（`8086:7af0`）/ `8087:0026` |
| 有线 | Motorcomm YT6801（`1f0a:6801`） |
| 键盘 / 触控板 | PS/2 键盘 + I2C 精密触控板 |
| 雷电 / 读卡器 | 本机无 |

## 2. 这套配置做了什么

- BIOS **MUX = 混合模式**：内屏挂在核显（`IGPU@2`），由 **WhateverXe** 驱动；
- 独显由 **NullMoth** 驱动（NVRM / NVAccel / NVRMFB / NVRMAGDC），与核显**同时加载**；
- 内屏：2560×1600、HiDPI（UI 1280×800）、亮度可调；
- 核显加速器准入打通（20/20 守卫通过），`IntelAccelerator` 正常实例化，
  Metal 插件 `AppleIntelTGLGraphicsMTLDriver` 运行，H.264/HEVC 解码能力上报为「是」；
- 视频播放的**硬解实际走 NVIDIA**（libnvdec），像素转换也由 NVIDIA 承担——
  Intel 的解码与像素转换在本机 15.8.2 上不可用，详见第 4.5 节与「不能用的」。

## 3. 能用的 / 不能用的

### 能用

| 功能 | 状态 |
|---|---|
| 内屏显示 + HiDPI | ✅ 2560×1600 |
| 亮度调节（滑块 / 亮度键） | ✅ |
| 独显 Metal（NVMTL，Metal 3 + 光追） | ✅ |
| 核显与独显共存 | ✅ 同时加载 |
| **核显加速（UI 由核显渲染）** | ✅ 需打补丁，见 4.5.1 |
| **控制中心 / 通知中心 / 菜单栏时钟 / 小部件** | ✅ 需打补丁，见 4.5.1 |
| **视频硬件解码（IINA / mpv / VLC / QuickTime / 网页）** | ✅ 走 NVIDIA，需打补丁，见 4.5.2 |
| 声卡 SN6140 | ✅ layout-id 15 |
| Wi-Fi AX201 / 蓝牙 | ✅ AirportItlwm + IntelBluetoothFirmware |
| 触控板（I2C 精密）/ 键盘 | ✅ |
| 电池、USB、摄像头 | ✅ |
| CPU 变频、温度传感器 | ✅ CPUFriend / SMCProcessor |
| 独显温度/占用/频率/功耗 | ✅ SMCNvidiaGPU |
| 有线网卡 YT6801 | ⚠️ 需另装用户态驱动，见第 4.6 节 |

### 不能用 / 有缺陷

| 项目 | 说明 |
|---|---|
| **Intel 核显硬件解码** | 在 15.8.2 上可建立解码会话但**出不了帧**（`-17696`，`avconvert` 转码 0%）。因此本方案让硬解全程走 NVIDIA |
| 睡眠 / 休眠 | 故意关闭（`SleepDisabled=1`），NVIDIA 唤醒后内屏不亮 |
| 风扇转速 | EC 直控，系统侧无接口；风扇自动温控本身正常 |
| 键盘背光 | EC 直控，Fn 快捷键可用，系统侧无接口 |
| 外接显示 / USB-C 输出 | 混合模式下未验证（WhateverXe 的 DP/USB-C 重连本就已知不稳） |
| App Store 视频 / FairPlay | 未验证 |
| 雷电、SD 读卡器 | 本机无硬件 |

## 4. 装完这份 EFI 之后，还必须做这些

EFI 只负责引导与内核补丁，**两套显卡驱动的本体都不在 EFI 里**，必须按顺序安装。

### 4.1 生成自己的三码（必做）

仓库里的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 是占位值。用
[GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成一套，填进
`PlatformInfo > Generic`，机型保持 `MacBookPro16,2`。
不换三码会导致 iCloud / iMessage / App Store 异常。

### 4.2 BIOS 设置

| 项 | 值 |
|---|---|
| 显卡模式（MUX / Graphics Switch） | **混合模式（Hybrid / Optimus）** |
| Above 4G Decoding | On |
| CSM | Off |
| Secure Boot | Off |
| DVMT Pre-Allocated（若有） | 96MB |

### 4.3 装独显驱动（NullMoth，官方）

- 项目：<https://github.com/nullmoth/nvidia-macos-driver>
- 安装器：<https://github.com/nullmoth/1401>
- 版本：**2.6.x**（NVRM / NVAccel / NVRMFB / NVRMAGDC / NVMTL），装到 `/Library/Extensions` 并重建 AuxKC；
- 装完在「系统设置 → 隐私与安全性」允许扩展，再重启；
- 本 EFI 已包含它需要的 `csr-active-config=0x0A43`、`nvfb=1 nvaccel=1 …` 与
  `Kernel > Block IONDRVSupport`。

### 4.4 装核显驱动包（WhateverXe Graphics，官方）

- WEX 插件：<https://github.com/b00t0x/WhateverXe>
- 驱动包：<https://github.com/b00t0x/WhateverXe-Graphics>
- 装 **WhateverXe Graphics 0.3.2 或更新版** 的 pkg（约 91MB），它会把
  `AppleIntelTGLGraphics*`、`AppleIntelTGLCompat`、GL/MTL/VA bundle 装进 `/Library` 并重建 AuxKC；
- 同时需要 **AMFIPass 1.4.1 Mod**（在上面的 WhateverXe-Graphics 仓库 `extras/` 里），
  本 EFI 的 `Kexts/AMFIPass.kext` 已是该 Mod 版；
- **顺序**：先用本 EFI 启动一次（确认 `kmutil showloaded | grep WhateverXe` 有输出）
  → 再装 pkg → 重启。

### 4.5 打本发布包提供的两个补丁（必做，官方包不包含）

装完 4.3 / 4.4 并重启后，会出现两个上游已知但未在 15.8.2 上适配的问题。
本发布包 `脚本/` 目录下提供两个一键补丁（都以 root 运行、可回滚）：

#### 4.5.1 `1-UI修复补丁.command` —— 修 UI 组件崩溃

- **症状**：核显加速一旦生效，控制中心打不开、右上角时钟消失、小部件呼不出、
  系统设置→显示器 拖动亮度条闪退。
- **原因**：驱动包里的 `impostor.dylib` 有一道
  `strcmp(kern.osversion, "24H32")` 门禁，只在特定 build 上安装
  binary-archive 兼容钩子；15.8.2（`24H232`）不匹配 → 钩子从未安装 →
  `RenderBox` 加载预编译着色器库时断言 `Target device architecture is nil`。
- **修复**：`impostor.dylib` 偏移 `0x2498` 处 `74 02`（je）改为 `EB 02`（jmp），
  无条件安装钩子；其余逻辑（方法签名校验、NVIDIA 设备转发）原样保留。补丁后整包重签。

#### 4.5.2 `2-视频硬解修复.command` —— 修播放器闪退 / 硬解不可用

- **症状**：IINA 等第三方播放器打开视频立即闪退（exit 90 或 SIGSEGV）；
  QuickTime / 网页视频也播不了。
- **原因**：三层叠加——
  1. Intel VA 驱动（`TGLVA`）同样有 `24H32` build 门禁，不匹配直接 `exit(90)`；
  2. 绕过门禁后，Intel 硬解在 15.8.2 上**仍解不出帧**（`-17696`）；
  3. NVIDIA 解码出的帧会被 VideoToolbox 交给 Intel 做**跨 GPU 像素转换**，
     Intel 的 pixel-process 在 15.8.2 上空指针崩溃（`KERN_INVALID_ADDRESS at 0x8`）。
- **修复**：把整个 `AppleIntelTGLGraphicsVADriver.bundle` 改名为 `.disabled`，
  让解码与像素转换**统一走 NVIDIA**，跨 GPU 冲突消失。
- **前提**：必须先装好 NullMoth 并确认独显正常（脚本会检查 `NVMTLDriver.bundle`）。

#### 执行顺序

```bash
# 装完 4.3 / 4.4 并重启后：
sudo bash 脚本/1-UI修复补丁.command      # 或直接双击 .command
sudo bash 脚本/2-视频硬解修复.command
# 重启
sudo bash 脚本/3-状态确认.sh             # 检查三项是否就位
```

### 4.6 有线网卡（可选，官方）

YT6801 走用户态驱动：<https://github.com/MiniYv/yt6801-for-macOS>，装完在系统设置里批准。

### 4.7 播放器建议

- **IINA**：<https://iina.io>，本方案下无需任何额外设置，硬解自动走 NVIDIA；
- 验证硬解：播放时看活动监视器 CPU（1080p 硬解约 2–5%），
  或运行 `脚本/3-状态确认.sh`（会检查 IINA 是否加载 `libnvdec`）。

## 5. 本发布包内容

```
EFI/                          OpenCore 0.1.0.8 完整 EFI（已含全部 kext）
驱动/WhateverXe.kext          自编译版：放宽 ADL-HX 内屏背光门禁 + 15.8.2 准入修复
驱动/SMCNvidiaGPU-源码与kext  独显温度/占用/频率/功耗传感器插件（含源码）
脚本/1-UI修复补丁.command      修控制中心/时钟/小部件崩溃
脚本/2-视频硬解修复.command    修播放器闪退、统一硬解到 NVIDIA
脚本/3-状态确认.sh            一键检查补丁状态 / 是否硬解 / 近期崩溃
脚本/4-回滚.command           撤销两个补丁
```

**关于 `WhateverXe.kext`**：本包内这份是从 0.6.1 源码自行编译的修改版，改了两处——
① 放宽 ADL-S/HX 内屏背光的写入门禁（原版要求 fuse bit24，本机为 0，亮度写不进去）；
② 加速器准入校验改为解析 rel32 目标符号（15.8.2 把 `_IOProtectCacheMode` 移动了 0x30 字节，
原版写死绝对位移会失配，导致准入 19/20）。功能等价。

## 6. 版本信息

| 项目 | 值 |
|---|---|
| macOS | 15.8.2（24H232） |
| OpenCore | 1.0.8（`REL-108-2026-09-27`） |
| 仿冒机型 | `MacBookPro16,2` |
| SIP | `csr-active-config = 0x0A43` |
| boot-args | `keepsyms=1 ipc_control_port_options=0 revpatch=auto,sbvmm,asset,cpuname nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=4 nvrmacpibl=1 -vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 dk=0x8001 -allow3d -disablegfxfirmware` |
| WhateverXe.kext | 0.6.1（本地修改版，含 15.8.2 准入修复） |
| WhateverXe Graphics | 0.3.2 或更新 |
| NullMoth | 2.6.x |
| SMCNvidiaGPU | 1.3.3 |

**启用的关键 kext**：Lilu 1.7.3、WhateverXe 0.6.1（本地修改版）、AMFIPass 1.4.1 Mod、
VirtualSMC 1.3.8、SMCNvidiaGPU 1.3.3、AppleALC、AirportItlwm、IntelBluetoothFirmware、
VoodooI2C/VoodooPS2、SMCBatteryManager、CpuTopologyRebuild、CPUFriend。

## 7. 出问题怎么退

| 状况 | 处理 |
|---|---|
| 内屏黑 / 起不来 | Windows 下把 U 盘 `EFI` 改名，换回自己的备份 EFI |
| UI 组件崩 | 运行 `脚本/4-回滚.command` 撤销两个补丁，或重装 WhateverXe Graphics pkg |
| 想完全撤销核显驱动 | `sudo bash uninstall.sh`（WhateverXe-Graphics 仓库根目录），再重启 |
| 打补丁后想复原 | `脚本/4-回滚.command`（会恢复 `impostor.dylib` 与 VA bundle） |

## 8. 致谢

- **核显驱动：[b00t0x](https://github.com/b00t0x)** —— WhateverXe 与 WhateverXe Graphics（BSD-3-Clause，衍生自 WhateverGreen），本配置的核显内屏与亮度全靠它；
- **独显驱动：[NullMoth](https://github.com/nullmoth)** —— nvidia-macos-driver / 1401（NVRM·NVAccel·NVMTL）；
- [Acidanthera](https://github.com/acidanthera)：OpenCore、Lilu、VirtualSMC、AppleALC、WhateverGreen、RestrictEvents、HibernationFixup；
- [dhinakg](https://github.com/dhinakg)：AMFIPass；[OpenIntelWireless](https://github.com/OpenIntelWireless)：AirportItlwm、IntelBluetoothFirmware；
- [laobamac](https://github.com/laobamac) 修复 macos 15.8.2 上的 WiFi 驱动，SimpleHDA音频驱动
- [VoodooI2C](https://github.com/VoodooI2C)、[VoodooPS2](https://github.com/acidanthera/VoodooPS2)：触控板与键盘；
- [MiniYv](https://github.com/MiniYv/yt6801-for-macOS)：YT6801 有线网卡驱动；
- [zzzyy678](https://github.com/zzzyy678/SMCNvidiaGPU)：SMCNvidiaGPU 传感器插件。
- 还有好多无法一一致谢，如有遗漏请联系我。

---

*本配置为个人实机验证记录，不保证在其他机器上可用。涉及二进制修改的操作（补丁脚本）请自行评估风险，建议先做系统备份。*
