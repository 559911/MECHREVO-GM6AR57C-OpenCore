# MECHREVO GM6AR57C · OpenCore EFI（Hybrid MUX · 核显内屏 + 无头独显）

**i7-12800HX · RTX 4070 Laptop · Intel UHD 0x4688 · AX201 · macOS Sequoia 15.8.2（24H232）**

发布版本：**v16 / 2026-11-14** · 对应本机 `EFI-版本/16-混合模式-核显内屏+独显-ForbiddenItlwm无线0.5.4-beta.2`

> 这份 EFI 让**内屏由核显驱动**、**独显无头常驻并承担 Metal 计算与 NVDEC 硬解**（BIOS 为混合模式 / MUX Hybrid）。
> 内屏 2560×1600、1440×900 HiDPI、亮度连续可调；熄屏唤醒不再黑屏；硬解走独显 NVDEC。
> **v16 起无线驱动换为 ForbiddenItlwm，AirDrop 可用。**
> 完整变更与验证数据见 [`RELEASE-NOTES-2026-11-14.md`](RELEASE-NOTES-2026-11-14.md)。

---

## 0. 先读这一段

1. **三码是占位值，必须自己生成。** 发布包 `EFI/OC/config.plist` 里的
   `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 已换成占位值。不换就用，
   iCloud、iMessage、App Store 会异常，也可能与别人的机器冲突。机型保持 `MacBookPro16,2`。
2. **两套显卡驱动的本体都不在 EFI 里。** NVRM / NVRMFB / NVRMAGDC / NVAccel（3.0）与
   WhateverXe Graphics（0.4.4）、AppleIntelTGLCompat（0.8.1）都装在 `/Library/Extensions` 等系统侧目录，
   属于 AuxKC。**只拷 EFI 不会有图形加速**；重装 macOS 后这些要全部重来。
3. **补丁与版本强绑定。** 两处 WhateverXe 本地补丁、`SMCNvidiaGPU` 的绑定表，都是在
   macOS **15.8.2（24H232）+ AppleIntelTGLGraphics 16.0.0 + NVRM 3.0** 上验证的。
   换系统 build 或换驱动版本都要重新验证。
4. **boot-args 不要按单一 README 精简。** WhateverXe 与 NullMoth / 1401 对同一参数的要求**相反**；
   本版还包含 ForbiddenItlwm 的 17 项参数。删错参数会直接导致启动失败、Firefox 等加固 App 崩溃，
   或 AirDrop 失效。
5. **ForbiddenItlwm 是实验性 beta。** 上游 README 明示「experimental beta」、有 AI 参与编写，
   可能导致内核 panic、bootloop、Wi-Fi 或蓝牙丢失。请保留一份可启动的回退介质，
   先在 U 盘上验证再考虑长期使用。

---

## 1. 硬件与工作方式

| 部件 | 型号 / 标识 |
|---|---|
| 机型 | MECHREVO GM6AR57C（同方 GM6AR57C 模具，16 英寸） |
| CPU | Intel Core i7-12800HX，8P+8E / 24 线程 |
| 核显 | Intel UHD Graphics `8086:4688`（Alder Lake-HX / ADL-S 级别） |
| 独显 | NVIDIA RTX 4070 Laptop `10de:2820`，8 GB，`NVAccelHeadless=Yes` |
| 内屏 | 2560×1600，EDID 标称 165 Hz，实际 60 Hz；1440×900 HiDPI（系统侧 override） |
| 无线 / 蓝牙 | Intel AX201 CNVi（`8086:7af0`）/ `8087:0026` |
| 声卡 | AppleALC（layout-id 15）+ SimpleHDA |
| 有线网 | YT6801（DriverKit DEXT，需另装） |

内屏走核显 `AppleIntelFramebuffer@0`；独显不接任何显示器，只做 Metal / OpenCL 计算与 NVDEC 解码。

### v16 主要变化

| 组件 | v14 | **v16** |
|---|---|---|
| Wi-Fi | `AirportItlwm.kext` 2.4.0 | **`ForbiddenItlwm.kext` 0.5.4-beta.2（Sequoia）** |
| 蓝牙广播 | `IntelBTPatcher.kext` 2.5.0 | **`BTLEAdvFixup.kext` 0.9.1（Sequoia）** |
| WhateverXe | 0.8.0 + 2 补丁（`5dbfbbbf…`） | **0.8.2 + 2 补丁**（`1e893782…`） |
| WhateverXe Graphics | 0.4.1（需打 MTL 泄漏补丁） | **0.4.4**（上游已修，**不再需要二进制补丁**） |
| NullMoth NVRM | 2.7.2 | **3.0** |
| SMCNvidiaGPU | 1.8.5（`794e8d06…`） | **2.1**（`97ef7b24…`，绑 NVRM 3.0） |
| `Kernel > Add` | 33 项 | **30 项**（28 启用 / 2 禁用） |
| EFI 文件数 / 体积 | 209 / 44,630,597 B | **205 / 44,154,059 B** |

删掉的 3 个长期禁用 kext：`IntelBTPatcher`（被 BTLEAdvFixup 接管）、`WhateverGreen`
（与 WhateverXe 互斥，功能全属 AMD/NVIDIA/Intel HD 补丁）、`FeatureUnlock`（本机机型原生支持）。
保留 `HibernationFixup`、`RTCMemoryFixup` 两个禁用备用项。

---

## 2. 快速开始

1. **生成并填入三码**（`SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM`），机型不要改。
2. **把 `EFI/` 放到引导介质**，先只引导一次，确认 kext 正常注入：
   ```bash
   kmutil showloaded | grep -iE 'whateverxe|forbiddenitlwm|btleadv'
   ```
   应当看到 `WhateverXe`、`org.forbiddenitlwm.ForbiddenItlwm`、`org.forbiddenitlwm.BTLEAdvFixup`，
   且**不应**看到 `AirportItlwm`、`IntelBTPatcher`。
3. **装系统侧驱动**：NullMoth NVRM 3.0（`/Library/Extensions`，重建 AuxKC）、
   WhateverXe Graphics 0.4.4、`AppleIntelTGLCompat` 0.8.1。
   - 0.4.4 的 `0x7ed87` 出厂即 `90 90`，**不再需要打 MTL 泄漏补丁或重签**。
   - `AppleIntelTGLGraphicsVADriver.bundle` 仍需保持 `.disabled`；装 pkg 前先删掉旧的
     `.disabled`，否则 `<relocate/>` 会把新载荷塞进旧目录。
4. **核对两处 WhateverXe 本地补丁与传感器绑定**：
   ```bash
   shasum -a 256 EFI/OC/Kexts/WhateverXe.kext/Contents/MacOS/WhateverXe
   # 1e8937825ec01993394488394626f860b81a9d823b7e2dc6775b4f739c1a5c60
   sysctl kern.nvgpustate   # 成功终态：polling mask 0xff / 500 ms
   ```
   两处补丁（上游 0.8.2 仍未修）：ADL-S 背光去 FUSE bit24 门禁、
   唤醒黑屏的面板供电 no-op。详见 `文档/本地补丁说明.md`。
5. **装 HiDPI override**、跑一遍 `脚本/4-重启后自检.command`，然后验证 AirDrop。

系统侧的完整分步说明（v14 时期撰写，版本号请以本页与发布说明为准）见
`文档/安装指南-v14-历史.md`。

---

## 3. 无线与 AirDrop

`ForbiddenItlwm` 是 `AirportItlwm` 的分支，加入 AWDL 让 macOS 自己的 Wi-Fi 栈能在 Intel 网卡上跑
AirDrop。官方 `docs/INSTALL.md` 明确点名 `24H232 (15.8.2) run those verified kernels`，
所以必须使用 **Sequoia** 构建；Tahoe / Sonoma 构建在本机不能启动。

两个 kext 的 `IOClass` 都叫 `AirportItlwm`、`IOPCIMatch` 完全相同，**绝不能共存**。
`IntelBTPatcher` 与 `BTLEAdvFixup` 钩同一函数，两者同钩会让 Lilu panic，故前者必须不加载。

### 运行时判据

```bash
ioreg -l -w0 | grep -E '"ItlwmAWDL(InterfaceBuild|BuildCheck)"|"ITLAWDLCoex(Added|Channel|CountryLearned)"'
ioreg -l -w0 -d1 | grep '"BTLEAdvHookRouted'
```

| 键 | 期望 |
|---|---|
| `ItlwmAWDLInterfaceBuild` | `forbidden-0.5.4-beta.2-sequoia` |
| `ItlwmAWDLBuildCheck` | `verified` |
| `ITLAWDLCoexAdded` / `CountryLearned` | `Yes` / `Yes` |
| `ITLAWDLCoexTxSubmitErrors` | `0` |
| `BTLEAdvHookRouted` | `1` |
| `awdl0` | 接口存在 |
| `ITLAWDLCoexChannel` | 与 Wi-Fi 当前信道一致（本版去掉了 `-itlawdlcoexmulti`） |

**关于 149 信道**：中国把 149–161 标为 passive，驱动不能主动开，必须先听到该频段的 beacon。
附近只有 36/40/48 时，`ITLAWDLCoexBeaconHints = 0`，早期配置会卡在 channel 6 而极慢。
按官方 `TROUBLESHOOTING.md` 去掉 `-itlawdlcoexmulti` 后，监听器跟随 Wi-Fi 自身信道，
AirDrop 可用；**把路由器 5 GHz 主信道改成 149（80 MHz）可达最佳速度**，改完等一分钟即可，
不需要再改 EFI。

⚠️ **升级 macOS 前必须先不带 `-btleadv` 启动一次**（或临时禁用 `BTLEAdvFixup`），
否则其内存补丁会让增量更新校验失败。升级后先确认新 build 在支持列表里再开回来。

---

## 4. 发布包里有什么

```
GitHub 发布版本/
├── README.md                            本文件
├── RELEASE-NOTES-2026-11-14.md          GitHub Release 页面说明（v16）
├── 发布步骤.md                          仓库上传 / Release / 发布前检查清单
├── .gitignore
├── EFI/                                 205 文件（仅三码脱敏，其余与 16 版逐字节一致）
├── 脚本/
│   ├── 1-装完Graphics包后补丁.command    用户态补丁（0.4.4 起 MTL 补丁已无必要）
│   ├── 2-安装HiDPI覆盖.command          1440x900 HiDPI（改完必须整机重启）
│   ├── 3-还原HiDPI覆盖.command
│   ├── 4-重启后自检.command             运行时判据逐项核对（只读）
│   ├── 5-熄屏唤醒回归.command           多轮长熄屏唤醒测试
│   └── 6-还原用户态补丁.command
├── 驱动/
│   ├── WhateverXe.kext/                 0.8.2 + 2 处本地补丁（1e893782…）
│   ├── SMCNvidiaGPU.kext/               2.1（97ef7b24…，绑 NVRM 3.0）
│   └── 源码/                            v14 时期的构建基线与补丁锚点脚本
├── 工具/
│   ├── 内屏HiDPI-1440x900/              override 文件、生成脚本、原版备份、说明
│   └── smcread / smcread.c              读 SMC 键的小工具
└── 文档/
    ├── 校验值.md                        全包与关键文件 SHA-256、脱敏说明
    ├── EFI文件清单-SHA256.txt           EFI 全树 205 文件逐文件哈希
    ├── boot-args逐项说明.md              启动参数逐项归属（含 ForbiddenItlwm 17 项）
    ├── 本地补丁说明.md                   两处补丁逐条、已作废项、升级注意
    ├── 安装指南-v14-历史.md              v14 完整安装排障指南（版本号已过时）
    └── 历史-RELEASE-NOTES-v14.md        v14 发布说明存档
```

---

## 5. 已知限制

- 睡眠 / 休眠永久关闭（独显唤醒后内屏不亮）；`HibernationFixup` 保留为禁用备用项。
- 内屏 165 Hz 用不上：EDID 是 384 B、DisplayID Type I 写了 2560×1600@165.002 Hz，
  但驱动只列 60 Hz、`IOFBTimingRange` 上限 720 MHz。**未实现、未验证**。
- 核显 VA 硬解主动禁用（AppleGVA 像素转换崩）；硬解走独显 NVDEC。
- 风扇转速无 SMC 接口（EC 直控，温控正常）；键盘背光 Fn 组合键可用。
- 无雷电 4、无 SD 读卡器（硬件本身没有）。
- 摄像头能枚举 Chicony UVC 且 TCC 已授权，会议 App 长时稳定性未实测，**不要断言已损坏**。
- AirDrop 速度受 149 信道可用性限制，见第 3 节。

---

## 6. 上游与致谢

| 项目 | 链接 |
|---|---|
| ForbiddenItlwm（AirDrop for Intel Wi-Fi） | <https://github.com/retropineaple/ForbiddenItlwm> |
| itlwm / AirportItlwm | <https://github.com/OpenIntelWireless/itlwm> |
| IntelBluetoothFirmware | <https://github.com/OpenIntelWireless/IntelBluetoothFirmware> |
| WhateverXe / WhateverXe-Graphics | <https://github.com/b00t0x/WhateverXe> · <https://github.com/b00t0x/WhateverXe-Graphics> |
| NullMoth nvidia-macos-driver / 1401 | <https://github.com/nullmoth/nvidia-macos-driver> · <https://github.com/nullmoth/1401> |
| OpenCore / Lilu / VirtualSMC / BlueToolFixup / WhateverGreen | <https://github.com/acidanthera> |
| SMCNvidiaGPU（VirtualSMC 插件） | <https://github.com/Carnations-Botanica/SMCNvidiaGPU> |

`ForbiddenItlwm` Wi-Fi 驱动为 GPL-2.0，`BTLEAdvFixup` 为 GPL-3.0-only；
其余组件许可见各自仓库。发布包内保留了上游 README 与 LICENSE。

上游 `nullmoth/nvidia-macos-driver` 的 CONTRIBUTING.md 明确不接受 AI 代写的代码、描述与缺陷报告，
且要求本人撰写并提供 Send logs 的 `NM-xxxx` ID；向该项目提交 Issue 请一律由本人执行。

---

## 7. 校验

```bash
shasum -a 256 EFI/OC/config.plist
plutil -lint  EFI/OC/config.plist
```

脱敏版 config 与自用 16 版的差异**只有 4 处三码**。全包（含二进制与 zip）
已对真实序列号 / MLB / UUID / ROM 做过扫描，零命中。逐文件哈希见
`文档/EFI文件清单-SHA256.txt`，关键指纹见 `文档/校验值.md`。

`1401` 安装器会在登录时自动改写引导介质上的 `config.plist`（boot-args、
`Kernel > Block`、`HideAuxiliary`）并替换 `OC/Tools/NullMothSafe.efi`，
**每次升级驱动后都要重新核对 config 指纹**。
