# MECHREVO GM6AR57C · OpenCore EFI（混合模式）

**i7-12800HX · RTX 4070 Laptop · Intel UHD（ADL-HX）· macOS Sequoia 15.8.2**

> 这份 EFI 让内屏走**核显**、独显同时可用（BIOS 设为混合模式 / MUX Hybrid）。
> 内屏 2560×1600 HiDPI 正常、亮度可调；独显 Metal 正常。
> **核显的 3D 与视频硬解目前未放行**，因此视频播放走软解会卡——详见「不能用的」。

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
- 核显帧缓冲走 WhateverXe 的 Alder Lake-S/HX 后端，`SSDT-PNLF` 提供背光锚点（`_UID=19`）。

## 3. 能用的 / 不能用的

### 能用

| 功能 | 状态 |
|---|---|
| 内屏显示 + HiDPI | ✅ 2560×1600 |
| 亮度调节（滑块 / 亮度键） | ✅ 本版修复 |
| 独显 Metal（NVMTL，Metal 3） | ✅ |
| 核显与独显共存 | ✅ 同时加载 |
| 声卡 SN6140 | ✅ layout-id 15 |
| Wi-Fi AX201 / 蓝牙 | ✅ AirportItlwm + IntelBluetoothFirmware |
| 触控板（I2C 精密）/ 键盘 | ✅ |
| 电池、USB、摄像头 | ✅ |
| CPU 变频、温度传感器 | ✅ CPUFriend / SMCProcessor |
| 独显温度/占用/频率/功耗 | ✅ SMCNvidiaGPU |
| 有线网卡 YT6801 | ⚠️ 需另装驱动，见第 4 节 |

### 不能用 / 有缺陷

| 项目 | 说明 |
|---|---|
| **核显 3D 与视频硬解** | WhateverXe 的加速器准入未通过（MMIO 非缓存路由的内核补丁校验在 15.8.2 上不匹配）。表现为桌面/视频走软件渲染，**视频会卡顿** |
| 睡眠 / 休眠 | 故意关闭（`SleepDisabled=1`），NVIDIA 唤醒后内屏不亮 |
| 风扇转速 | EC 直控，系统侧无接口；风扇自动温控本身正常 |
| 外接显示 / USB-C 输出 | 混合模式下未验证（DisplayPort/USB-C 重连在 WhateverXe 上本就已知不稳） |
| App Store 视频 / FairPlay | 核显路径不支持 |
| 雷电、SD 读卡器 | 本机无硬件 |

## 4. 装完这份 EFI 之后，还必须装这些

EFI 只负责引导和核显补丁，**两套显卡驱动的本体都不在 EFI 里**。

### 4.1 先生成自己的三码（必做）

仓库里的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 是占位值。用
[GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成一套，填进
`PlatformInfo > Generic`，机型保持 `MacBookPro16,2`。不换三码会导致 iCloud / iMessage / App Store 异常。

### 4.2 BIOS 设置

| 项 | 值 |
|---|---|
| 显卡模式（MUX / Graphics Switch） | **混合模式（Hybrid / Optimus）** |
| Above 4G Decoding | On |
| CSM | Off |
| Secure Boot | Off |
| DVMT Pre-Allocated（若有） | 96MB |

### 4.3 装独显驱动（NullMoth）

- 项目：<https://github.com/nullmoth/nvidia-macos-driver>，安装器：<https://github.com/nullmoth/1401>
- 版本：**2.6.3**（NVRM / NVAccel / NVRMFB / NVRMAGDC），装到 `/Library/Extensions` 并重建 AuxKC；
- 装完在「系统设置 → 隐私与安全性」允许扩展，再重启；
- 本仓库的 EFI 已经包含它需要的 `csr-active-config=0x0A43`、`nvfb=1 nvaccel=1 …`、`Kernel > Block IONDRVSupport`。

### 4.4 装核显驱动包（WhateverXe Graphics）

- 项目：<https://github.com/b00t0x/WhateverXe>（补丁）+ <https://github.com/b00t0x/WhateverXe-Graphics>（驱动包）
- 装 **WhateverXe Graphics 0.3.2.pkg**（约 91MB），它会把 `AppleIntelTGLGraphics*`、`AppleIntelTGLCompat`、GL/MTL/VA bundle 装进 `/Library` 并重建 AuxKC；
- **顺序**：先用本 EFI 启动一次（确认 `kmutil showloaded | grep WhateverXe` 有输出）→ 再装 pkg → 重启。

### 4.5 有线网卡（可选）

YT6801 走用户态驱动：<https://github.com/MiniYv/yt6801-for-macOS>，装完在系统设置里批准。

## 5. 版本信息

| 项目 | 值 |
|---|---|
| macOS | 15.8.2（24H232） |
| OpenCore | 1.0.8（`REL-108-2026-09-27`） |
| 仿冒机型 | `MacBookPro16,2` |
| SIP | `csr-active-config = 0x0A43` |
| boot-args | `keepsyms=1 ipc_control_port_options=0 revpatch=auto,sbvmm,asset,cpuname nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=4 nvrmacpibl=1 -vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 dk=0x8001 -allow3d -disablegfxfirmware` |

**启用的关键 kext**：Lilu 1.7.3、WhateverXe 0.6.1（本地修改版）、AMFIPass 1.4.1 Mod、VirtualSMC 1.3.8、SMCNvidiaGPU 1.3.3、AppleALC、AirportItlwm、IntelBluetoothFirmware、VoodooI2C/VoodooPS2、SMCBatteryManager、CpuTopologyRebuild、CPUFriend。

**关于 `WhateverXe.kext`**：仓库里这份是从 0.6.1 源码自行编译的修改版，只改了一处——放宽 ADL-S/HX 内屏背光的写入门禁（原版要求 fuse bit24，本机为 0，导致亮度永远写不进去）。功能等价，另带 `ADLSBL` / `ADMIT` 前缀的诊断日志，属正常输出。官方原版可从 WhateverXe Releases 获取。

## 6. 出问题怎么退

- 内屏黑 / 起不来：Windows 下把 U 盘 `EFI` 改名，换回你自己的备份 EFI；
- 装完 pkg 后想撤销：`sudo bash uninstall.sh`（脚本在 WhateverXe-Graphics 仓库根目录），再重启。

## 7. 致谢

- **核显驱动：[b00t0x](https://github.com/b00t0x)** —— WhateverXe 与 WhateverXe Graphics（BSD-3-Clause，衍生自 WhateverGreen），本配置的核显内屏与亮度全靠它；
- **独显驱动：[NullMoth](https://github.com/nullmoth)** —— nvidia-macos-driver / 1401（NVRM·NVAccel·NVMTL）；
- [Acidanthera](https://github.com/acidanthera)：OpenCore、Lilu、VirtualSMC、AppleALC、WhateverGreen、RestrictEvents、HibernationFixup；
- [dhinakg](https://github.com/dhinakg)：AMFIPass；[OpenIntelWireless](https://github.com/OpenIntelWireless)：AirportItlwm、IntelBluetoothFirmware；
- [laobamac](https://github.com/laobamac) 修复 macos 15.8.2 上的 WiFi 驱动，SimpleHDA音频驱动
- [VoodooI2C](https://github.com/VoodooI2C)、[VoodooPS2](https://github.com/acidanthera/VoodooPS2)：触控板与键盘；
- [MiniYv](https://github.com/MiniYv/yt6801-for-macOS)：YT6801 有线网卡驱动；
- [zzzyy678](https://github.com/zzzyy678/SMCNvidiaGPU)：SMCNvidiaGPU 传感器插件。
- 还有好多无法一一致谢，如有遗漏请联系我。
