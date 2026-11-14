# boot-args 逐项归属说明（v16 / 2026-11-14）

`EFI/OC/config.plist` → `NVRAM > Add > 7C436110-AB2A-4BBB-A880-FE41995C9F82 > boot-args` 当前完整内容（**34 项**）：

```
keepsyms=1 ipc_control_port_options=0 revpatch=auto,sbvmm,asset,cpuname nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=1 -vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 dk=0x8001 -allow3d -disablegfxfirmware -nopsr nvrmacpibl=1 -nodisplaysleepDC6 -btleadv -itlawdlcoexprobe -itlawdliface -itlawdlnativeup -itlawdlcoexrx -itlawdlcoextx -itlawdlcoexdata -itlawdlmitx -itlawdlelicit -itlawdlcaps -itlawdlsvcmerge -itlawdlawsync itlawdlintcoal=4 -itlawdlcoexbatx -itlawdlcoexpeerpause -itlawdlcoexbatrace itlawdltxqueue=4096
```

> **不要按任何单一 README 精简。** WhateverXe 与 NullMoth / 1401 是两套驱动，
> 对同一参数的要求可能相反；本版又多了 ForbiddenItlwm 的一套参数。
> 下面逐项标明归属，依据均来自各项目作者本人的 README、安装脚本或排障文档原文。

## 一、原有 17 项的归属裁决

| 参数 | 归属 | 官方依据 | 裁决 |
|---|---|---|---|
| `-allow3d -disablegfxfirmware` | WhateverXe | WEX README「Required boot arguments」原文 | **必须保留** |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | NullMoth / 1401 | `nullmoth-setup.sh` 第 6 行逐字：`WANT_ARGS="nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0"` | **必须保留**。WEX README 说 `amfi=0x80` / `ipc_control_port_options=0` unnecessary，只对 WEX 单方面成立 |
| `csr-active-config`（`0xA43`） | NullMoth / 1401 | `nullmoth-setup.sh`：`SIP_BITS=$((0x0A43))` | **保持**。WEX 要 `0x803`，两套要求不同，以驱动安装器为准 |
| `-nodisplaysleepDC6` | 苹果帧缓冲驱动 | 项目实测：`start` 置 `+0xC29=0`，`setDCState` 跳过 `enableHWDC6/SWDC6`；多轮唤醒回归通过 | **必须保留**（替代已删除的 P3） |
| `-nopsr` | 苹果帧缓冲驱动 | 该驱动启动参数之一 | 保持；删除前须单独 A/B 验证 |
| `nvrmacpibl=1` | 1401「Built-in screen brightness」开关 | 官方文案只适用于内屏接独显的 MUX Discrete 机型，本机是 Hybrid MUX、内屏接核显 | **唯一明确不适用本机的项**。当前零故障，属可选清理候选，改前必须单独 A/B |
| `nvfbhidpi=1`（当前**未**设置） | 1401「HiDPI modes」开关 | — | **不要加**。本机 HiDPI 走核显 + `/Library/Displays` override，独显无头 |
| `gfxrst=1` | 用户侧 | 官方脚本：「A gfxrst the user set stays as it is」 | **保持 1，不要改成 4** |
| `keepsyms=1`、`revpatch=auto,sbvmm,asset,cpuname`、`dk=0x8001`、`-vi2c-force-polling` | 其他来源 | 不在 WEX 与 1401 的官方必需清单中 | 历史遗留。**不要一次全删**，如要精简须逐项 A/B |

WEX 0.8.x README 逐字：

> "Use the linked **Mod** AMFIPass instead of upstream AMFIPass; do not load both.
> WhateverGreen and WhateverXe must not be enabled together. `amfi=0x80` and
> `ipc_control_port_options=0` are unnecessary."

这句「unnecessary」**只对 WhateverXe 成立**；1401 的安装脚本把它们列在 `WANT_ARGS` 里，
删掉会导致 Firefox 等加固 App 在 task control port 上崩溃。

## 二、ForbiddenItlwm / BTLEAdvFixup 的 17 项（v16 新增）

依据上游 `docs/BOOT-FLAGS.md` 的 "The tested set"。官方原文：

> "AirDrop is off unless its flags are set, so with none of them ForbiddenItlwm behaves like
> AirportItlwm. The beta needs a long list of flags. **They are the exact set used for every
> tested result.**"

| 参数 | 作用（官方原文释义） |
|---|---|
| `-btleadv` | 开启 BTLEAdvFixup，让 `bluetoothd` 能在 Intel 控制器上发 BLE 广播 |
| `-itlawdlcoexprobe` | 在正常 Wi-Fi station 旁边增加第二个固件上下文（AWDL 监听器） |
| `-itlawdliface` | 告诉 macOS 网卡支持 AWDL，创建 `awdl0` 接口 |
| `-itlawdlnativeup` | 接受让 macOS 的 AWDL peer manager 启动的请求 |
| `-itlawdlcoexrx` | 把监听器收到的 AWDL 帧交给 macOS |
| `-itlawdlcoextx` | 给监听器独立的固件 station 与队列，并从它发送 macOS 的同步帧 |
| `-itlawdlcoexdata` | 让 AirDrop 数据双向经过监听器 |
| `-itlawdlmitx` | 在同步帧里发送 macOS 自己的 AWDL 公告；只在已验证 build 上生效 |
| `-itlawdlelicit` | 补齐 Apple 设备期待的选举参数、信道序列与 HT 能力 |
| `-itlawdlcaps` | 上报 2 空间流与 VHT，让 iPhone 用 80 MHz 双流速率 |
| `-itlawdlsvcmerge` | 把 macOS 的服务记录合并进公告帧，改善发现 |
| `-itlawdlawsync` | 按 iPhone 的可用窗口安排空闲同步帧 |
| `itlawdlintcoal=4` | 缩短监听器中断合并，降低延迟 |
| `-itlawdlcoexbatx` | 出站 Block Ack 与固件聚合，Mac → iPhone 变快的关键 |
| `-itlawdlcoexpeerpause` | iPhone 调度离开时暂停其固件队列，避免浪费帧 |
| `-itlawdlcoexbatrace` | 在 IORegistry 记录 Block Ack 事件，供缺陷报告用（诊断项，开销低） |
| `itlawdltxqueue=4096` | `awdl0` 驱动自身发送队列大小 |

### 本版去掉了 `-itlawdlcoexmulti`

官方 "The tested set" 共 18 项，其中 `-itlawdlcoexmulti` 用于「让监听器独立占用 149 信道（80 MHz）」。
中国把 149–161 标为 **passive**，官方 `docs/TROUBLESHOOTING.md` 原文：

> "**Channels 149 to 161 marked passive (China, for example)**: ... once the hackintosh hears
> a Wi-Fi network's beacon on one of these channels, the listener may use it, as on Linux.
> `ITLAWDLCoexBeaconHints` shows which channels were heard ... **With no network on them nearby,
> AirDrop stays on 6.**"

本机实测 `ITLAWDLCoexBeaconHints = 0`（附近 5 GHz 只有 36/40/48），
监听器因此卡在 `ITLAWDLCoexChannel = 6`，官方对 channel 6 的描述是
`on 6, everything is very slow`。

按同一文档的对策去掉该参数，其余 17 项全保留：

> "**Wi-Fi keeps dropping and reconnecting while the AirDrop flags are on, or channel 149 isn't
> available on your network:** remove `-itlawdlcoexmulti` and keep the rest. The listener then
> stays on your Wi-Fi network's channel instead of its own. Wi-Fi stays stable (#16), and
> AirDrop works where 149 can't be used (#29)."

去掉后实测 `ITLAWDLCoexChannel = 36`，与 Wi-Fi 当前信道一致。
**把路由器 5 GHz 主信道改成 149（80 MHz）仍可达到最佳速度**，改完等一分钟即可，不必再改 EFI。

### 明确不要加的参数

- `-itlawdlcoexlowlat`：官方 "Don't use"，AX211 上固件会拒绝该命令并让正常 Wi-Fi 掉线。
- `-itlawdlrx` 及监视模式系列（`-itlawdlqueue`、`-itlawdl6`、`itlawdlcc=` 等）：会让网卡进入 monitor mode，正常 Wi-Fi 断开。
- `itlwm_cc`：官方明确「只改 macOS 显示的国家码，**不会打开信道 149**」。
- `-itlawdlanybuild`：在未验证的 macOS build 上强开 AirDrop，有 panic 风险，本机 `24H232` 已被官方验证，不需要。

## 三、升级 macOS 前的操作

官方 `docs/INSTALL.md`：

> "**Boot once without `-btleadv` (or with BTLEAdvFixup disabled), then update.** While
> BTLEAdvFixup is active, `bluetoothd`'s patched pages are what the system reads, and an
> incremental update that checks the file can fail."

升级完成、确认新 build 在 `docs/TESTED-HARDWARE.md` 支持列表里之后，再把 `-btleadv` 加回来。

## 四、NVRAM 写入

`boot-args` 已列在 `NVRAM > Delete > 7C436110-AB2A-4BBB-A880-FE41995C9F82` 中，
OpenCore 每次启动会先删后写，所以改 `config.plist` 后**必须重启**才生效。
核对方式：

```bash
nvram boot-args | tr ' ' '\n' | wc -l     # 34
nvram boot-args | grep -o -- '-itlawdlcoexmulti' || echo "已按本版去掉"
```
