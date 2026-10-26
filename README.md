# MECHREVO GM6AR57C · OpenCore EFI

**Intel i7-12800HX · NVIDIA RTX 4070 Laptop · macOS Sequoia 15.8.1**

> **English summary**
> OpenCore EFI for the MECHREVO GM6AR57C (Tongfang GM6AR57C barebone): Intel Core i7-12800HX + RTX 4070 Laptop, macOS 15.8.1. Graphics run on the community **NullMoth** NVIDIA driver (NVK + NVMTL, Metal 3, 165 Hz). This laptop runs its internal panel on the dGPU only, so there is no Intel iGPU path: hardware video decode is unavailable and sleep/hibernation is deliberately disabled. Please read the "What does not work" section before using, and **generate your own SMBIOS** — the serials in this repo are placeholders.
å
---

## ⚠️ 使用前必读

1. **三码是占位值。** 本仓库 `config.plist` 里的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 已替换为占位字符串。直接使用会导致 iCloud、iMessage、App Store 无法正常工作。请用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成你自己的三码，填入 `PlatformInfo > Generic`。
2. **只适用于这一款机器。** 同方 GM6AR57C 模具（机械革命 GM6AR57C / 部分同模具机型）。别的机型套用大概率起不来。
3. **显卡驱动是非官方社区项目。** 它把 NVIDIA 的开源内核模块（NVK）移植到 macOS，再通过 NVMTL 把 Metal 转到 Vulkan 上。仍在活跃开发，**不建议作为唯一工作系统**。
4. **睡眠和休眠是故意关掉的。** 原因见「为什么要关掉睡眠」。

---

## 1. 硬件配置

| 部件 | 型号 / 标识 |
|---|---|
| 机型 | MECHREVO GM6AR57C（同方 GM6AR57C 模具，16 英寸） |
| CPU | Intel Core i7-12800HX，8 P-core + 8 E-core / 24 线程，55W |
| 独显 | NVIDIA GeForce RTX 4070 Laptop（AD106M，10de:2820，8GB GDDR6） |
| 核显 | Intel UHD Graphics（Alder Lake-P，8086:4688）——本机 BIOS 设为**独显直连**，核显不出现在 PCI 总线上 |
| 内存 | 16GB DDR5-4800（板载不可换，Crucial CT16G56C46S5） |
| 硬盘 | KINGSTON OM8PGP41024N-A0，1TB NVMe（PCIe 4.0 x4） |
| 屏幕 | 2560×1600 @ 165Hz，16 英寸（BOE 面板，EDID `09e5:0a1f`） |
| 声卡 | Conexant **SN6140**（14f1:1f87，subsystem 1d05:3008） |
| 无线 | Intel **AX201** CNVi（8086:7af0） |
| 蓝牙 | Intel（8087:0026，USB 接口） |
| 有线网卡 | Motorcomm **YT6801**（1f0a:6801）—— **无 macOS 驱动** |
| 摄像头 | Chicony HD Webcam（04f2:b78a，UVC） |
| 键盘 / 触控板 | PS/2 键盘 + I2C 精密触控板 |
| 电池 | 5200 mAh，60W 电源适配器 |
| 读卡器 / 雷电 | 本机没有 |

## 2. 软件版本

| 项目 | 版本 |
|---|---|
| macOS | 15.8.1（24H32，Sequoia） |
| OpenCore | 1.0.x |
| 仿冒机型 | `MacBookPro16,2` |
| NVIDIA 驱动 | NullMoth 2.5.4（NVRM / NVAccel / NVRMFB / NVRMAGDC） |

## 3. 驱动与插件

### 启用的

| Kext | 版本 | 用途 |
|---|---|---|
| Lilu | 1.7.3 | 内核补丁框架，多数 kext 的前置 |
| VirtualSMC | 1.3.8 | 仿冒 SMC 芯片 |
| SMCProcessor | 1.3.8 | CPU 温度传感器 |
| SMCBatteryManager | 1.3.8 | 电池电量 |
| ECEnabler | 1.0.6 | 读取超过 8 位的 EC 字段 |
| AMFIPass | 1.4.1 | 放行未签名驱动 |
| WhateverGreen | 1.7.1 | 显卡通用补丁 |
| AppleALC | 1.9.8 | 声卡注入（SN6140，layout 15） |
| SimpleHDA | 1.0.0 | 声卡控制器侧的补充注入 |
| RestrictEvents | 1.1.7 | 修正 CPU 名称显示、屏蔽部分机型限制 |
| CPUFriend | 1.3.1 | 加载自定义变频数据 |
| CPUFriendDataProvider | 1.0.1 | 变频数据本体 |
| CpuTopologyRebuild | 2.0.2 | 修正 P/E 混合架构的核心拓扑 |
| CpuTscSync | 1.1.2 | 多核 TSC 同步 |
| USBMap | 1.0 | 定制 USB 端口（12 个端口） |
| VoodooI2C | 2.9.1 | I2C 触控板 |
| VoodooI2CHID | 1.0 | I2C HID 设备 |
| VoodooPS2Controller | 2.3.8 | PS/2 键盘 |
| VoodooInput | 1.1.6 | 多点触控输入抽象 |
| BrightnessKeys | 1.0.3 | 亮度快捷键 |
| AirportItlwm | 2.4.0 | Intel 无线网卡 |
| IntelBluetoothFirmware | 2.5.0 | Intel 蓝牙固件加载 |
| IntelBTPatcher | 2.5.0 | 蓝牙补丁 |
| BlueToolFixup | 2.6.9 | macOS 12+ 蓝牙修复 |

> 说明：`VoodooI2C.kext` 内部还带 `VoodooI2CServices`、`VoodooGPIO`、`VoodooInput` 三个插件，随主驱动一起加载，在 `config.plist` 里各占一条记录。所以磁盘上是 **26 个 .kext**，config 里是 **30 条**（27 条启用 / 3 条禁用）。

### 装了但禁用的（备用）

| Kext | 版本 | 为什么禁用 |
|---|---|---|
| HibernationFixup | 1.5.5 | 休眠已整体关闭，没有作用对象 |
| RTCMemoryFixup | 1.0.8 | 没有 RTC 冲突，`rtc-blacklist` 为空 |
| FeatureUnlock | 1.1.9 | 本机机型 `MacBookPro16,2` 原生支持随航/隔空播放，不需要解锁 |

## 4. ACPI

| SSDT | 用途 |
|---|---|
| SSDT-AWAC | 本机 DSDT 含 AWAC 设备，强制走 RTC |
| SSDT-EC-USBX-LAPTOP | 补充 EC 与 USB 供电属性 |
| SSDT-PLUG-ALT | 注入 `plugin-type=1`，启用 XCPM 原生电源管理 |
| SSDT-XOSI | 配合 `_OSI → XOSI` 重命名 |
| SSDT-PNLF | **已禁用**。背光由 NVIDIA 驱动提供，不需要走 Intel 通路 |

ACPI 重命名：`_OSI → XOSI`、`HDAS → HDEF`。

## 5. 运行状态

### ✅ 能工作

| 项目 | 状态 |
|---|---|
| 显卡加速 | Metal 3 正常，`NVAccel` 已加载，GPU 通过 PCIe 4.0 x8 连接 |
| 内屏 | 2560×1600 @ **165Hz**，HiDPI 缩放正常 |
| 亮度调节 | 正常（含 Fn 快捷键） |
| 音频 | 内置扬声器 + 内置麦克风，layout 15 |
| 电池 | 电量、充电状态、循环次数均正确 |
| 触控板 | I2C 精密触控板，多指手势正常 |
| 键盘 | 正常 |
| 摄像头 | 正常（UVC） |
| Wi-Fi | 802.11ac，2.4G / 5G 全信道 |
| 蓝牙 | 可连接外设 |
| 硬盘 | 原生 NVMe，TRIM 开启 |
| USB | 全部端口可用（含内建摄像头与蓝牙端口） |
| CPU 电源管理 | XCPM 生效，温度可读 |
| iCloud / App Store | 换过三码后正常 |

### ❌ 不能工作（附原因）

| 项目 | 原因 |
|---|---|
| **硬件视频解码** | 本机没有可用的核显（BIOS 独显直连，且 macOS 不支持 12 代核显），独显的 NVDEC 在 macOS 没有接口。H.264 / HEVC 全部软解，**看 4K 和开视频会议时 CPU 占用和发热明显** |
| **硬件视频编码** | RTX 4070 属 Ada 架构，当前驱动还没有 Ada 的编码器，已用 `NVMTL_NO_NVENC=1` 主动回退到软件编码 |
| **睡眠 / 休眠** | 独显无法在唤醒时重新点亮面板：S3 卡在固件握手（`Sleep Wake Failure in EFI`），休眠卡在开机恢复。已彻底关闭 |
| **有线网卡** | YT6801 没有 macOS 驱动，厂商只提供 Windows / Linux |
| **HDMI / DP 音频** | 独显自带的 HDA 控制器（10de:22bd）没有驱动接管 |
| **隔空投送 / 随航 / 接力 / 通用控制 / AirPlay 接收** | 全部依赖 AWDL，而 Intel 网卡配 itlwm 不实现这一层（`awdl0` 接口不存在） |
| **Wi-Fi 6** | itlwm 只实现到 802.11ac |
| **风扇转速 / 风扇调速** | 风扇挂在 EC 上，macOS 没有通用读取路径 |

### ⚠️ 未测试

- 耳机孔自动切换（驱动暴露了多路输出引擎，理论支持）
- iMessage / FaceTime 收发
- 外接显示器与投屏到 Apple TV
- 键盘背光（如果由 EC 硬件快捷键控制则可用）

## 6. 关键配置说明

### boot-args

```
keepsyms=1 ipc_control_port_options=0 revpatch=auto,sbvmm,asset,cpuname
nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=4 nvrmacpibl=1
-vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 -v
```

- `revpatch=...,cpuname` —— RestrictEvents 让关于本机显示真实 CPU 型号
- `nvfb / nvaccel / nvfbheads / -nvkmsnosmooth / gfxrst / nvrmacpibl` —— NullMoth 显卡驱动的参数
- `-vi2c-force-polling` —— 触控板走轮询模式
- `amfi=0x80` 与 `amfi_get_out_of_my_way=0x1` —— 关闭 AMFI，驱动未签名必需
- `-v` —— 保留详细启动日志，排查问题用

### 为什么要关掉睡眠

这台机器内屏挂在独显上。睡眠唤醒需要显卡重新 POST 并点亮面板，而 NullMoth 驱动没有实现 `restoreMachineState`。实测结果：

- S3 睡眠：诊断报告 `Sleep Wake failure in EFI`，失败码 `0x1f`，只能长按电源
- 休眠（hibernatemode 25）：镜像能成功写盘（8GB），但开机时不会续接

所以最终用 `Misc > Boot > HibernateMode = None` 让 OpenCore 完全忽略休眠，系统侧用 `disablesleep 1` 彻底禁止睡眠。

**⚠️ 副作用：合盖不再睡眠，整机继续运行。装进包里之前必须关机，否则会在密闭空间里持续发热。**

### 为什么没有核显注入

BIOS 设为独显直连后，核显在 PCI 总线上根本不存在。给一个不存在的设备注入 `AAPL,ig-platform-id` 没有意义，反而会让 WhateverGreen 打上 `ffffffff` 占位值。`DeviceProperties` 因此只注入了 HDA（`layout-id 15`）。

### 引导菜单

`UIScale = 2`。因为面板是 2560×1600，1:1 渲染的菜单在 16 寸屏上小得看不清。

## 7. 使用方法

```bash
# 1) 生成你自己的三码（需要 Python 3）
git clone https://github.com/corpnewt/GenSMBIOS
cd GenSMBIOS && ./GenSMBIOS.command
#    选 3 (Generate SMBIOS)，机型输入 MacBookPro16,2
#    把得到的 Serial / MLB / SmUUID 填进 config.plist 的 PlatformInfo > Generic
#    ROM 填你网卡的 MAC 地址（12 位十六进制转成 6 字节）

# 2) 把 EFI 文件夹放到 EFI 分区的根目录
#    结构应为 /EFI/BOOT/BOOTx64.efi 与 /EFI/OC/
```

BIOS 里需要确认：

- **Secure Boot：关闭**
- **显卡模式：独显直连**（Hybrid / 混合输出模式不适用本配置）
- VT-d：保持默认即可，本 EFI 用 `Kernel > Quirks > DisableIoMapper` 处理
- 如果启动卡在 `EXITBS:START`：先关 VT-d；仍不行再关超线程

首次启动建议先在 U 盘上试，确认能进系统再写入内置磁盘。

## 8. 已知问题

- **视频解码全靠 CPU**。4K 视频、视频会议、视频导出都会明显吃 CPU，风扇转速升高。
- **NVIDIA 驱动在电源状态切换上还不稳定**。我的记录里出现过 WindowServer 意外退出和关机卡顿，判断与驱动版本有关，属上游问题。
- **无 AWDL**，苹果生态的互联功能基本都不可用。要这些功能只能换博通网卡（BCM94360NG），且需确认 M.2 插槽有 PCIe 通道——本机原装是 CNVi 接口，部分插槽只走 CNVi 信号。
- Wi-Fi 走 itlwm，速率上限约 802.11ac，且不能与原生 Airport 驱动共存。

## 9. 致谢

- [NullMoth Systems](https://github.com/nullmoth/nvidia-macos-driver) —— NVIDIA Metal 驱动
- [Acidanthera](https://github.com/acidanthera) —— OpenCore、Lilu、VirtualSMC、WhateverGreen、AppleALC 等
- [zxystd](https://github.com/OpenIntelWireless) —— itlwm / AirportItlwm、IntelBluetoothFirmware
- [alexandred](https://github.com/VoodooI2C) —— VoodooI2C
- [b00t0x](https://github.com/b00t0x) —— CpuTopologyRebuild
- [laobamac](https://github.com/laobamac) —— SimpleHDA
- [1Revenger1](https://github.com/1Revenger1) —— ECEnabler

## 10. 更新日志

- **2026-10-26** —— 首次发布。
