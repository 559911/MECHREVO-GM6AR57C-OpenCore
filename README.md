# MECHREVO GM6AR57C · OpenCore EFI

**Intel i7-12800HX · NVIDIA RTX 4070 Laptop · macOS Sequoia 15.8.1**

> **English summary**
> OpenCore EFI for the MECHREVO GM6AR57C (Tongfang GM6AR57C barebone): Intel Core i7-12800HX + RTX 4070 Laptop, macOS 15.8.1. Graphics run on the community **NullMoth** NVIDIA driver (NVK + NVMTL, Metal 3, 165 Hz). This laptop runs its internal panel on the dGPU only, so there is no Intel iGPU path: hardware video decode is unavailable and sleep/hibernation is deliberately disabled. Please read the "What does not work" section before using, and **generate your own SMBIOS** — the serials in this repo are placeholders. The bundled SMCNvidiaGPU plugin exposes GPU temperature, utilisation, clocks and power through SMC / PerformanceStatistics (section 8).

---

## ⚠️ 使用前必读

1. **三码是占位值。** 本仓库 `config.plist` 里的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 已替换为占位字符串。直接使用会导致 iCloud、iMessage、App Store 无法正常工作。请用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成你自己的三码，填入 `PlatformInfo > Generic`。
2. **只适用于这一款机器。** 同方 GM6AR57C 模具（机械革命 GM6AR57C / 部分同模具机型）。别的机型套用大概率起不来。
3. **显卡驱动是非官方社区项目，而且不在本仓库里。** NullMoth 把 NVIDIA 的开源内核模块（NVK）移植到 macOS，再通过 NVMTL 把 Metal 转到 Vulkan 上；它安装在 `/Library/Extensions`，本仓库的 EFI 只负责引导和传感器，**不含驱动本体**。仍在活跃开发，**不建议作为唯一工作系统**。
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
| 有线网卡 | Motorcomm **YT6801**（1f0a:6801）—— 第三方 DEXT 驱动可用，见第 9 节 |
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
| NVIDIA 驱动 | NullMoth 2.6.2（NVRM / NVAccel / NVRMFB / NVRMAGDC） |

## 3. 驱动与插件

### 启用的

| Kext | 版本 | 用途 |
|---|---|---|
| Lilu | 1.7.3 | 内核补丁框架，多数 kext 的前置 |
| VirtualSMC | 1.3.8 | 仿冒 SMC 芯片 |
| SMCProcessor | 1.3.8 | CPU 温度传感器 |
| SMCNvidiaGPU | 1.3.2 | GPU 温度、占用率、核心/显存频率、显存、功耗（VirtualSMC 插件，见第 8 节） |
| SMCBatteryManager | 1.3.8 | 电池电量 |
| ECEnabler | 1.0.6 | 读取超过 8 位的 EC 字段 |
| AMFIPass | 1.4.1 | 放行未签名驱动 |
| WhateverGreen | 1.7.1 | 显卡通用补丁 |
| AppleALC | 1.9.8 | 声卡注入（SN6140，layout 15） |
| SimpleHDA | 1.0.0 | 声卡控制器侧的补充注入 |
| RestrictEvents | 1.1.7 | 修正 CPU 名称显示、屏蔽部分机型限制 |
| CPUFriend | 1.3.1 | 加载自定义变频数据 |
| CPUFriendDataProvider | 1.0.2 | 变频数据本体（LFM 800MHz / CPUFloor 800） |
| CpuTopologyRebuild | 2.0.2 | 修正 P/E 混合架构的核心拓扑 |
| CpuTscSync | 1.1.2 | 多核 TSC 同步 |
| USBMap | 1.0 | 定制 USB 端口（12 个端口） |
| VoodooI2C | 2.9.1 | I2C 触控板 |
| VoodooI2CHID | 1.0 | I2C HID 设备 |
| VoodooPS2Controller | 2.3.8 | PS/2 键盘 |
| VoodooInput | 1.1.6 | 多点触控输入抽象 |
| BrightnessKeys | 1.0.3 | 亮度快捷键 |
| AirportItlwm | 2.4.0 | Intel 无线网卡（laobamac 维护的 Sequoia 构建，基于 OpenIntelWireless） |
| IntelBluetoothFirmware | 2.5.0 | Intel 蓝牙固件加载 |
| IntelBTPatcher | 2.5.0 | 蓝牙补丁 |
| BlueToolFixup | 2.6.9 | macOS 12+ 蓝牙修复 |

> 说明：`VoodooI2C.kext` 内部还带 `VoodooI2CServices`、`VoodooGPIO`、`VoodooInput` 三个插件，随主驱动一起加载，在 `config.plist` 里各占一条记录。所以磁盘上是 **27 个 .kext**，config 里是 **31 条**（28 条启用 / 3 条禁用）。

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
| 有线网卡 | YT6801 可用，走系统侧 DEXT 驱动（不在 EFI 里） |
| 硬盘 | 原生 NVMe，TRIM 开启 |
| USB | 全部端口可用（含内建摄像头与蓝牙端口） |
| CPU 电源管理 | XCPM 生效，P/E 核心变频正常；封装功耗空闲 15–18W，温度可读 |
| GPU 传感器 | 温度、占用率、核心/显存频率、显存用量、功耗可读（`SMCNvidiaGPU`）；驱动不深度降频，空载也停在 2175MHz |
| iCloud / App Store | 换过三码后正常 |

### ❌ 不能工作（附原因）

| 项目 | 原因 |
|---|---|
| **硬件视频解码** | 本机没有可用的核显（BIOS 独显直连，且 macOS 不支持 12 代核显），独显的 NVDEC 在 macOS 没有接口。H.264 / HEVC 全部软解，**看 4K 和开视频会议时 CPU 占用和发热明显** |
| **硬件视频编码** | RTX 4070 属 Ada 架构，当前驱动还没有 Ada 的编码器，已用 `NVMTL_NO_NVENC=1` 主动回退到软件编码 |
| **睡眠 / 休眠** | 独显无法在唤醒时重新点亮面板：S3 卡在固件握手（`Sleep Wake Failure in EFI`），休眠卡在开机恢复。已彻底关闭 |
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
-vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80
```

- `revpatch=...,cpuname` —— RestrictEvents 让关于本机显示真实 CPU 型号
- `nvfb / nvaccel / nvfbheads / -nvkmsnosmooth / gfxrst / nvrmacpibl` —— NullMoth 显卡驱动的参数
- `-vi2c-force-polling` —— 触控板走轮询模式
- `amfi=0x80` 与 `amfi_get_out_of_my_way=0x1` —— 关闭 AMFI，驱动未签名必需
- 启动日志改由 `Misc > Debug > Target=65` 落盘到 EFI 分区，不再用 `-v` 滚屏

### CPU 变频数据

`CPUFriend` + `CPUFriendDataProvider` 覆盖 macOS 给仿冒机型准备的电源配置。本机仿冒 `MacBookPro16,2`，而苹果从没出过 12 代酷睿的 Mac——64 个 Mac 机型共用同一套 7668 字节模板，只有前 11 个数据块是每机型调校区，**不含核心数与电压表**。真正能调的只有 `LFM`、`EPP`、`PerfBias` 三个字段。

首版沿用了别处的数据，`LFM = 0x0D`，等于把最低频率-电压工作点钉在 **1300MHz**，空载也不许再低。本版按本机 SMBIOS 对应的原厂配置文件重建：

| 项目 | 首版 | 本版 |
|---|---|---|
| pmspFile | 12 | 13 |
| FrequencyVectors | 1 条 | 2 条 |
| LFM（最低频率工作点） | 1300MHz | **800MHz** |
| CPUFloor | 未设置 | 800 |

另外删掉了原厂配置里的 `Frequencies` 表。那份是 `MacBookPro16,2`（Ice Lake）的睿频档位，写着 3.8 / 4.1GHz，与 12800HX 的 4.8GHz 不符，留着会把睿频上限往 4.1GHz 带。

实测：`machdep.xcpm.hard_plimit_max_100mhz_ratio = 48`，**4.8GHz 睿频未受限**；封装温度 52–67℃，封装功耗空闲 15–18W（改前 20.5W）。

### 有线网卡

YT6801 走的是系统侧 DriverKit 驱动（DEXT），不是 kext，**不在 EFI 里**，也不会随 EFI 迁移。安装、批准、验证与卸载的完整步骤见第 9 节。

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

## 7. 安装 EFI

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

仓库根目录的 `tools/smcread` 是一个直接读 SMC 的小工具（源码同目录），用来确认温度/传感器是否注册，用法见第 8 节。


## 8. GPU 传感器（SMCNvidiaGPU）

EFI 里带了一个 VirtualSMC 插件 `SMCNvidiaGPU.kext`（1.3.2），作用是把 NVIDIA 驱动的读数接到 SMC 上。**它不是显卡驱动**——显卡由 NullMoth 驱动，EFI 不包含也不会安装 NullMoth。

### 8.1 它提供什么

SMC 键（iStat Menus 的 GPU 面板、多数传感器工具读这里）：

| SMC 键 | 内容 | 类型 |
|---|---|---|
| `TG0D` `TG0P` `TG0d` `TG0p` | GPU 温度（℃） | `sp78` |

同时写进 `NVAccel` 节点的 `PerformanceStatistics`（AppleMonitorCenter、AMD Power Gadget 一类工具读这里）：

| 键 | 内容 | 来源 |
|---|---|---|
| `Temperature(C)` `GPU Temperature(C)` | 温度 | 驱动已发布的属性 |
| `Device Utilization %` `GPU Core Utilization` | 占用率 | RM 内部 client |
| `Core Clock(MHz)` `Memory Clock(MHz)` | 核心 / 显存频率 | RM 内部 client |
| `Total Power(W)` `Power Limit(W)` | 功耗 / 功耗上限 | RUSD（GSP 共享内存） |
| `vramUsedBytes` `vramTotalBytes` | 显存用量 / 总量 | 驱动属性 + RUSD |
| `PCIe Gen` `PCIe Width` | 链路代数 / 宽度 | IOPCIExpress 寄存器 |

**不提供 GPU 风扇转速**。本机独显没有风扇，系统风扇挂在 EC 上（`FNum=0`）；插件也刻意不注册 `F2Ac/F3Ac`，否则监控软件会多出两行永远 0 RPM 的假风扇。

### 8.2 装 EFI 之前必须确认的事

1. **NullMoth 驱动已经在系统里。** 它装在 `/Library/Extensions`（NVRM / NVAccel / NVRMFB / NVRMAGDC），**不在 EFI 里**，换 EFI 不会丢也不会装：

   ```bash
   kmutil showloaded --list-only | grep -i nullmoth
   # 期望 4 条：NVRM / NVAccel / NVRMFB / NVRMAGDC，版本 2.6.2
   ```

   没有的话，先按 NullMoth 的说明装驱动；否则插件只会停在 `waiting for NVRM`，温度也没有。

2. **EFI 里的 Lilu、VirtualSMC 必须启用**，顺序为 Lilu → VirtualSMC → SMCNvidiaGPU（本包已经排好）。

3. **本包的插件是按 NullMoth 2.6.2 编的。** 换驱动版本后：

   - 温度照常——它读的是驱动自己发布的属性；
   - 占用率/频率/功耗不会出来——绑定表对不上，插件主动放弃，**不会崩、不会卡死**；
   - 需要这些数据时，要按新驱动重编一次插件（见 8.6）。

4. **装完 EFI 必须重启。** 这类 kext 只能开机注入，没有运行时加载的办法（`kmutil load` 会因为链接不到 VirtualSMC 符号而失败）。

### 8.3 重启后怎么确认

```bash
# 1) 插件是否加载
kmutil showloaded --list-only | grep SMCNvidiaGPU
# 期望：org.nullmoth.SMCNvidiaGPU (1.3.2)

# 2) 温度是否读到
sysctl kern.nvgpustate kern.nvgputemp kern.nvgputemp_src
# 期望：nvgputemp 在 30–90 之间；nvgputemp_src: 1

# 3) SMC 键是否注册（用仓库自带的小工具）
tools/smcread k TG0P TG0D
# 期望：TG0P sp78 len=2 val=xx.000
```

第三行如果提示 `TG0P 不存在`，说明插件没提交到 SMC，回到第 1 步查加载。

### 8.4 日常怎么调

所有开关都是 `sysctl`，**立即生效，重启后回到默认值**。默认已经是“温度 + 占用率/频率/功耗全开”，平时不用动。

| 键 | 默认 | 作用 | 怎么用 |
|---|---|---|---|
| `kern.nvgpurusd` | `1` | 深路径总开关：`1` 读占用率/频率/功耗；`0` 只读温度 | `sudo sysctl -w kern.nvgpurusd=0` |
| `kern.nvgputemp_mode` | `0` | 温度来源：`0` RM 边缘温度；`1`–`5` RUSD 的第 1–5 个传感器（热点/显存等） | `sudo sysctl -w kern.nvgputemp_mode=2` |
| `kern.nvgpufanmax` | `3500` | 风扇百分比的分母（本机无 GPU 风扇，用不到） | 仅台式机需要 |
| `kern.nvgpuvbios_override` | 空 | VBIOS 读不到时手工填 | `sudo sysctl -w kern.nvgpuvbios_override="95.06.1A.00.0B"` |

想临时关掉整个插件：boot-args 加 `nvsensoff=1`（本仓库的 `config.plist` 里 `boot-args` 加一项即可，改完重启）。只想关深路径、保留温度：`sudo sysctl -w kern.nvgpurusd=0`；要长期生效就写一个 LaunchDaemon 在开机时执行这条命令。

只读诊断键（不用改，直接看）：

```bash
sysctl kern.nvgpustate kern.nvgpulayout kern.nvgpupoll kern.nvgpulive
sysctl kern.nvgutil kern.nvggpcclk kern.nvgdramclk kern.nvgpupower kern.nvgputgp
sysctl kern.nvgpupwrlimit kern.nvgvramused kern.nvgvramtotal kern.nvgputhrottle
```

读数换算：`nvgutil` 是百分比 ×100（`869` = 8.69%）；功耗单位 mW；频率 MHz。`nvgputhrottle` 的 **bit0 是 `idle`**（空载标记，不是降频），bit2 才是 `sw-power-cap`。

### 8.5 状态行对照（排错用）

| `kern.nvgpustate` | 含义 | 处理 |
|---|---|---|
| `temperature from NVAccel ... (deep path off)` | 深路径关着，只有温度 | 正常（如果你设了 `nvgpurusd=0`） |
| `started, waiting for NVRM` | 驱动还没起来 | 等 10 秒；一直这样说明 NullMoth 没装或没加载 |
| `bound NVRM 0x… layout 0x…` | 绑定成功，深路径可用 | 正常 |
| `... does not match nvrm_bindings.h (driver updated?)` | 绑定表和当前驱动对不上 | 温度可用；要占用率需按新驱动重编（8.6） |
| `entry points ... do not match the expected build` | 同上（入口点字节校验失败） | 同上 |
| `waiting for NVRM to attach the GPU` | 驱动在，GPU 还没挂上 | 再等；持续这样查驱动日志 |

### 8.6 换驱动后重编（可选）

插件来自 [zzzyy678/SMCNvidiaGPU](https://github.com/zzzyy678/SMCNvidiaGPU/releases)（本 EFI 内为 1.3.2 本机适配版）。要点：**必须在同一台机器上编**，因为构建脚本会从本机 `/Library/Extensions/NVRM.kext` 现取偏移与签名；换驱动后重跑一次 `kext/build.sh` 即可。

本机 1.3.2 的编译参数：

```bash
MODE=release EXTRA_DEFINES="-DSMCNVG_NO_FANS" ./kext/build.sh build
```

`-DSMCNVG_NO_FANS` 是笔记本用的：不注册 GPU 风扇键。

### 8.7 卸载

`config.plist` → `Kernel > Add` → 把 `SMCNvidiaGPU.kext` 的 `Enabled` 改成 `false`（或删掉该条目），再删除 `EFI/OC/Kexts/SMCNvidiaGPU.kext`，重启。SMC 温度键随之消失，对显卡本身没有任何影响。

---

## 9. 有线网卡（YT6801）

本机有线网卡是 Motorcomm **YT6801**（`1f0a:6801`），macOS 没有原生支持。可用的是 [MiniYv/yt6801-for-macOS](https://github.com/MiniYv/yt6801-for-macOS) 的**用户态 DriverKit 驱动**（DEXT）：

- 不是 kext，**不放进 EFI**，也不会随 EFI 迁移；
- 换 EFI、重装 OpenCore 都不影响它；
- 只装一次，之后每次 macOS 大版本升级可能要重新批准。

### 9.1 安装

1. 从 [Releases](https://github.com/MiniYv/yt6801-for-macOS/releases) 下载 `YT6801-Installer-1.0.13.dmg`（或更新版本）；
2. 双击挂载，运行安装器；宿主程序会装到 `/Applications/YT6801Driver.app`；
3. 安装器同时注册系统扩展，**此时还不会生效**，必须进系统设置批准（9.2）。

### 9.2 进 macOS 后必须做的批准

图形界面路径：

1. 打开「系统设置」→「通用」→「登录项与扩展」；
2. 拉到最下面「驱动扩展」，找到 **YT6801**，把开关打开；
3. 如果弹出「系统扩展已被阻止」，去「隐私与安全性」，在底部点「允许」；
4. 期间可能要求输入管理员密码，或重启一次。

命令行核对：

```bash
systemextensionsctl list | grep yt6801
```

- `[activated waiting for user]` —— 还没批准，回到第 2 步；
- `[activated enabled]` —— 已生效。

> 本机 SIP 已放宽（`csr-active-config = 0x0a`）。如果你的机器 SIP 全开、系统设置里找不到「驱动扩展」，需要进恢复模式降低安全性后再批准。

### 9.3 验证

```bash
networksetup -listallhardwareports     # 应多出一个 Ethernet
ifconfig | grep -A3 "^en[0-9]"
system_profiler SPEthernetDataType
```

插上网线应自动拿到 DHCP 地址，`ping -c 3 223.5.5.5` 能通。千兆链路的实测下载约 894 Mbps。

### 9.4 一个必须注意的坑：`en0`

本机 Wi-Fi 是 `en0`，iCloud / App Store 的绑定在这个接口上。有线网卡正常会拿到 `en1`，不影响；但如果你发现 App Store 或 iCloud 异常，先查：

```bash
networksetup -listallhardwareports
```

确认 `en0` 仍然是 Wi-Fi。万一被抢了，删除 `/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist` 后重启，让系统重新排序（会清掉网络偏好设置，需要重连 Wi-Fi）。

### 9.5 卸载

```bash
/Applications/YT6801Driver.app/Contents/MacOS/yt6801host --deactivate
```

然后删掉 `/Applications/YT6801Driver.app`；必要时用 `systemextensionsctl uninstall <teamID> io.miniyv.yt6801ethernet`。

## 10. 已知问题

- **视频解码全靠 CPU**。4K 视频、视频会议、视频导出都会明显吃 CPU，风扇转速升高。
- **NVIDIA 驱动在电源状态切换上还不稳定**。我的记录里出现过 WindowServer 意外退出和关机卡顿，判断与驱动版本有关，属上游问题。
- **无 AWDL**，苹果生态的互联功能基本都不可用。要这些功能只能换博通网卡（BCM94360NG），且需确认 M.2 插槽有 PCIe 通道——本机原装是 CNVi 接口，部分插槽只走 CNVi 信号。
- Wi-Fi 走 itlwm，速率上限约 802.11ac，且不能与原生 Airport 驱动共存。

## 11. 致谢

**1. 引导与内核框架**

- [Acidanthera](https://github.com/acidanthera) —— OpenCore、Lilu、VirtualSMC、SMCProcessor、SMCBatteryManager、WhateverGreen、CPUFriend、RestrictEvents、BrightnessKeys、VoodooPS2Controller、HibernationFixup、RTCMemoryFixup、FeatureUnlock、BlueToolFixup
- [Dhinak G.](https://github.com/dhinakg) —— AMFIPass
- [lvs1974](https://github.com/lvs1974) —— CpuTscSync

**2. 显卡与显示**

- [NullMoth Systems](https://github.com/nullmoth/nvidia-macos-driver) —— NVIDIA Metal 驱动（NVRM / NVAccel / NVRMFB / NVRMAGDC），本机内屏与 Metal 全靠它
- [zzzyy678](https://github.com/zzzyy678/SMCNvidiaGPU/releases) —— **SMCNvidiaGPU**：把 GPU 温度、占用率、核心/显存频率、显存、功耗接进 SMC 的 VirtualSMC 插件（本 EFI 内的 1.3.2）

**3. 无线与蓝牙**

- [zxystd / OpenIntelWireless](https://github.com/OpenIntelWireless) —— itlwm / AirportItlwm 上游、IntelBluetoothFirmware、IntelBTPatcher
- [laobamac](https://github.com/laobamac) —— **AirportItlwm 的 Sequoia 构建**（本 EFI 内的 2.4.0 出自其维护版本，基于 OpenIntelWireless）

**4. 音频**

- [Acidanthera](https://github.com/acidanthera) —— AppleALC（SN6140，layout 15）
- [laobamac](https://github.com/laobamac) —— SimpleHDA（声卡控制器侧的补充注入）

**5. 有线网卡**

- [MiniYv](https://github.com/MiniYv/yt6801-for-macOS) —— YT6801 的 DriverKit 驱动（DEXT，不在 EFI 内）

**6. 输入**

- [alexandred](https://github.com/VoodooI2C) —— VoodooI2C、VoodooInput

**7. 电源、电池与配套工具**

- [1Revenger1](https://github.com/1Revenger1) —— ECEnabler
- [b00t0x](https://github.com/b00t0x) —— CpuTopologyRebuild
- [corpnewt](https://github.com/corpnewt) —— USBMap、GenSMBIOS

**8. 文档与规则**

- [Dortania](https://dortania.github.io/OpenCore-Install-Guide/) —— OpenCore 安装与排错指南
- 1401 自检规则（`efi_rules.json`）—— 本 EFI 的 Booter / Debug / Security 项按其判定修正

**9. 本机自写**

- `tools/smcread` —— 直接读 AppleSMC 的小工具，源码同目录，不属于第三方

如果上面漏了哪位，或者你希望换一种署名方式，开个 Issue 告诉我，我改。
