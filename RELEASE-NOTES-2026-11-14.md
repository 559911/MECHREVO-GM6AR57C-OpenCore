# v16 · 2026-11-14 · ForbiddenItlwm 无线（AirDrop）+ 上游同步

**MECHREVO GM6AR57C / i7-12800HX / RTX 4070 Laptop / AX201 / macOS 15.8.2（24H232）· Hybrid MUX**

本版把 Intel 无线驱动从 `AirportItlwm` 换成 `ForbiddenItlwm`，让这台机器的 **AirDrop 与随航相关功能可用**；
同时把显卡栈同步到上游新版本，并清掉 3 个长期禁用的无用 kext。

## 一、本版内容

| 组件 | v14（上一发布版） | **v16（本版）** |
|---|---|---|
| Intel Wi-Fi 驱动 | `AirportItlwm.kext` 2.4.0 | **`ForbiddenItlwm.kext` 0.5.4-beta.2（Sequoia 构建）** |
| 蓝牙广播 | `IntelBTPatcher.kext` 2.5.0 | **`BTLEAdvFixup.kext` 0.9.1（Sequoia 构建）** |
| WhateverXe（EFI 内 kext） | 0.8.0 + 2 处本地补丁（`5dbfbbbf…`） | **0.8.2 + 2 处本地补丁**（`1e893782…`） |
| WhateverXe Graphics（系统侧 pkg） | 0.4.1 | **0.4.4**（上游已修 MTL 泄漏，不再需要二进制补丁） |
| NullMoth NVRM | 2.7.2 | **3.0** |
| SMCNvidiaGPU | 1.8.5（`794e8d06…`，绑 2.7.2） | **2.1**（`97ef7b24…`，绑 NVRM 3.0，anchor `0x1a1c0`） |
| `Kernel > Add` 条目 | 33 | **30**（28 启用 / 2 禁用） |
| `OC/Kexts` | 29 个 | **26 个** |
| EFI 文件数 / 体积 | 209 / 44,630,597 B | **205 / 44,154,059 B** |
| config（自用版） | `17badb08` | **`0bdcc1d7`**（36,080 B） |

## 二、主要改动

### 1. 无线：AirportItlwm → ForbiddenItlwm

`ForbiddenItlwm` 是 `AirportItlwm` 的分支，加入 AWDL（Apple Wireless Direct Link），
让 macOS 自己的 Wi-Fi 栈能在 Intel 网卡上跑 AirDrop。上游 `docs/INSTALL.md` 逐字点名
本机系统版本：

> **Sequoia:** `24H23` (15.8) and `24H241` (15.8.3) were checked offline, and `24H32` (15.8.1) and
> **`24H232` (15.8.2) run those verified kernels**. Use the Sequoia kexts.

两个 kext 的 `IOKitPersonalities` 里 `IOClass` 仍叫 `AirportItlwm`、`IOPCIMatch` 完全相同，
**两者绝不能共存**，所以 `AirportItlwm.kext` 是移除而非改名保留。

`BTLEAdvFixup` 负责让 `bluetoothd` 能在 Intel 控制器上发 BLE 广播；它与 `IntelBTPatcher`
钩同一个函数，官方 INSTALL 明确要求禁用后者：

> **Disable `IntelBTPatcher.kext`.** It and BTLEAdvFixup hook the same function, and Lilu panics
> if two plugins do. BTLEAdvFixup takes over IntelBTPatcher's job.

`Kernel > Add` 按官方顺序重排为
`Lilu → IntelBluetoothFirmware → BlueToolFixup → BTLEAdvFixup → ForbiddenItlwm`，
后两者带 `MinKernel/MaxKernel` 24.0.0 / 24.99.99。

### 2. boot-args

追加官方 `docs/BOOT-FLAGS.md` 的 "The tested set" 18 项，原有 17 项一字未删。
本版**去掉其中 `-itlawdlcoexmulti`**（现 34 项），原因见第四节。

### 3. 清理 3 个长期禁用的无用 kext（条目与文件一并删除）

| 已删 | 依据 |
|---|---|
| `IntelBTPatcher.kext` | 功能已被 `BTLEAdvFixup` 接管，且两者不能共存 |
| `WhateverGreen.kext` | 官方 README 功能全属 AMD Radeon / NVIDIA web driver / Intel HD 补丁；本机核显由 WhateverXe 接管、独显由 NVRM 接管，且与 WhateverXe 互斥 |
| `FeatureUnlock.kext` | 本机 `MacBookPro16,2` 原生支持相关功能 |

**保留两个禁用备用项**：`HibernationFixup.kext`（未来可能修休眠；官方 README 说明它只服务
hibernate，与常规 sleep 无关，启用前须先把 `HibernateMode` 改回 `Auto`）、
`RTCMemoryFixup.kext`（唤醒异常时的应急手段）。

### 4. 显卡栈同步

- `WhateverXe` 0.8.2 + 2 处本地补丁（ADL-S 背光去 FUSE bit24 门禁、唤醒黑屏面板供电 no-op），
  上游仍未修；`kern_xe.cpp` 第三处同门禁只服务 Display13，本机死代码，故意不改。
- `WhateverXe Graphics` 0.4.4：上游自 0.4.2 修了 MTL 命令缓冲泄漏（#47），0.4.4 的
  `0x7ed87` 出厂即 `90 90`。**今后装 Graphics pkg 不再需要打二进制补丁或重签**，
  只需确认该偏移是 `9090`；VADriver 仍需保持 `.disabled`。
- `NVRM` 3.0 → `SMCNvidiaGPU` 2.1 按本机二进制重新生成绑定表并重编。
- 2.9 起独显空闲功耗由约 20.4 W 降到约 **1.8 W / 210 MHz**（按 burst 升频），
  RTX 4070 报 **Metal 3**；NVENC 在 Ada 上开始工作。

## 三、验证结果

两次重启实测（13:56 / 14:06，macOS 15.8.2 24H232）：

| 判据 | 实测 |
|---|---|
| `ItlwmAWDLInterfaceBuild` | `forbidden-0.5.4-beta.2-sequoia` |
| `ItlwmAWDLBuildCheck` | `verified` |
| `ITLAWDLCoexAdded` / `CountryLearned` | `Yes` / `Yes` |
| `ITLAWDLCoexTxSubmitErrors` / `CountryNotices` | `0` / `3` |
| `ItlwmAWDLPoolType` / `awdl0` | `1` / 已创建 |
| `BTLEAdvHookRouted` | `1` |
| `ITLAWDLCoexChannel` | 去掉 `-itlawdlcoexmulti` 后 `36`，与 Wi-Fi 信道一致 |
| `kmutil showloaded` | 只有 `org.forbiddenitlwm.*`；旧 `AirportItlwm` 与 `IntelBTPatcher` 均未加载 |
| Wi-Fi | 已连接、`en0` 拿到 IP、`AirDrop: Supported`、`Auto Unlock: Supported` |

装前 `tools/compat/check_compat.sh` 全项通过：网卡 `0x7af0`（AX201），
`BTLEAdvFixup` 四个特征码在 24H232 的 `bluetoothd` 上各命中 1 次。

## 四、已知限制与注意

- **AirDrop 信道**：中国把 149–161 标为 passive。本机 `ITLAWDLCoexBeaconHints = 0`
  （附近 5 GHz 只有 36/40/48），驱动听不到 149 的 beacon，早期会卡在 channel 6。
  按官方 `TROUBLESHOOTING.md` 去掉 `-itlawdlcoexmulti` 后监听器跟随 Wi-Fi 自身信道，
  AirDrop 可用，但速度不如 149/80。**把路由器 5 GHz 主信道改成 149（80 MHz）可达最佳状态**，
  改完等一分钟，不需要再改 EFI。
- **升级 macOS 前必须先不带 `-btleadv` 启动一次**（或临时禁用 `BTLEAdvFixup`），
  否则 BTLEAdvFixup 的内存补丁会让增量更新校验失败。升级后先确认新 build 在支持列表里再开回来。
- ForbiddenItlwm 上游 README 明示为 **experimental beta**、有 AI 参与编写，
  可能导致 panic / bootloop / Wi-Fi 或蓝牙丢失；建议保留可启动的回退介质。
- 睡眠 / 休眠永久关闭；内屏 165 Hz 未实现（EDID 与帧缓冲上限）；核显 VA 硬解主动禁用；
  风扇转速无 SMC 接口（EC 直控，温控正常）；键盘背光 Fn 可用。
- 1401 安装器登录后会自动改写引导介质上的 `config.plist`，每次升级驱动后须重新核对指纹。

## 五、安装

1. **先填三码**：`EFI/OC/config.plist` 的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM`
   都是占位值，必须自行生成，机型保持 `MacBookPro16,2`。
2. **只拷 EFI 不会有图形加速**：NVRM / NVRMFB / NVRMAGDC / NVAccel（3.0）、
   `WhateverXe Graphics` 0.4.4、`AppleIntelTGLCompat` 0.8.1 都装在
   `/Library/Extensions` 等系统侧目录，属 AuxKC，重装系统要重装。
3. 装完 Graphics 0.4.4 **不需要**再打 MTL 泄漏补丁；VADriver 保持 `.disabled`。
4. 换 NVRM 时必须按新二进制重新生成绑定表并重编 `SMCNvidiaGPU`；
   出现 `matches none of the N known builds` 就是驱动换了。
5. 部署后核对 config 指纹，并跑一遍发布包里的 `脚本/4-重启后自检.command`。

历史安装指南（v14 时期撰写，系统侧部分步骤仍适用，但其中 NVRM 2.7.2 / Graphics 0.4.1 /
SMCNvidiaGPU 1.8.5 等版本号已过时）见 `文档/安装指南-v14-历史.md`。

## 六、三码

`EFI/OC/config.plist` 的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 均为占位值，
**必须自行生成并填入**。发布包已对全部文本与二进制（含 zip 内每个条目）做过真实三码扫描，零命中。

## 七、附件

Release 附件为 `MECHREVO-GM6AR57C-EFI-v16.zip`，含 `EFI/`、`脚本/`、`驱动/`、`工具/`、
`文档/` 与本说明。中文文件名均带 UTF-8 标志，6 个 `.command` 保留可执行位。

附件的体积与 SHA-256 **在本 Release 页面末尾给出**（说明文本本身也在附件内，
故不在此文件里写死）。下载后请先核对哈希再使用。

