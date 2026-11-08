# boot-args 逐项归属说明

`EFI/OC/config.plist` → `NVRAM > Add > 7C436110-AB2A-4BBB-A880-FE41995C9F82 > boot-args` 当前完整内容：

```
keepsyms=1 ipc_control_port_options=0 revpatch=auto,sbvmm,asset,cpuname nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=1 -vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 dk=0x8001 -allow3d -disablegfxfirmware -nopsr nvrmacpibl=1 -nodisplaysleepDC6
```

> **不要按任何单一 README 精简。** WhateverXe 与 NullMoth / 1401 是两套驱动，对同一参数的要求可能相反。
> 下面逐项标明归属，依据均来自各项目作者本人的 README 或安装脚本原文。

## 一、逐项裁决

| 参数 | 归属 | 官方依据 | 裁决 |
|---|---|---|---|
| `-allow3d -disablegfxfirmware` | WhateverXe | WEX README「### Required boot arguments」原文 | **必须保留** |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | NullMoth / 1401 | `nullmoth-setup.sh` 第 6 行逐字：`WANT_ARGS="nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0"` | **必须保留**。WEX README 说 `amfi=0x80` / `ipc_control_port_options=0` unnecessary，只对 WEX 单方面成立 |
| `csr-active-config`（`0xA43`） | NullMoth / 1401 | `nullmoth-setup.sh` 第 31 行：`SIP_BITS=$((0x0A43))` | **保持**。WEX 要 `0x803`，两套要求不同，以驱动安装器为准 |
| `-nodisplaysleepDC6` | 苹果帧缓冲驱动 | 项目实测：`start` 置 `+0xC29=0`，`setDCState` 在 `0x47336`/`0x4746B` 跳过 `enableHWDC6/SWDC6`；8 轮唤醒回归通过 | **必须保留**（替代已删除的 P3） |
| `-nopsr` | 苹果帧缓冲驱动 | 该驱动 23 个启动参数之一 | 保持；删除前须单独 A/B 验证 |
| `nvrmacpibl=1` | 1401「Built-in screen brightness」开关 | 界面文档原文：「For a laptop whose built-in screen is wired to the NVIDIA GPU (MUX set to Discrete or dGPU)... **It is off by default because that call stopped some PCs at GPU start**」 | **唯一明确不适用本机的项**。本机 Hybrid MUX、内屏接核显，亮度由 WEX P1 实现。当前零故障，属**可选清理候选**，改前必须单独 A/B，不要顺手删 |
| `nvfbhidpi=1`（当前**未**设置） | 1401「HiDPI modes」开关 | 官方：`nvfbhidpi=1 lets NVRMFB back a "looks like" mode...` | **不要加**。本机 1440×900 HiDPI 走核显 + `/Library/Displays` override，独显无头 |
| `gfxrst=1` | 用户侧 | 官方脚本：「A gfxrst the user set stays as it is」；安装器只在检测到 WhateverGreen 时才加 `gfxrst=4` | **保持 1，不要改成 4** |
| `keepsyms=1`、`revpatch=auto,sbvmm,asset,cpuname`、`dk=0x8001`、`-vi2c-force-polling` | 其他来源 | 不在 WEX 与 1401 的官方必需清单中 | 历史遗留，无明显收益但也未见危害。**不要一次全删**，如要精简须逐项 A/B 验证 |

## 二、为什么 `amfi=0x80` / `ipc_control_port_options=0` 不能删

WEX 0.8.0 README 第 55 行逐字：

> "Use the linked **Mod** AMFIPass instead of upstream AMFIPass; do not load both. WhateverGreen and WhateverXe must not be enabled together. `amfi=0x80` and `ipc_control_port_options=0` are unnecessary."

这说的是**只考虑 WhateverXe 时**它们不必要。但 `nullmoth-setup.sh` 把这两个参数列进 `WANT_ARGS`，
并在第 4–5 行注释里写明 `ipc_control_port_options=0` 是为避免
「with AMFI relaxed, Firefox and other hardened apps crash at launch on their task control port」。
本机两套驱动同时加载，删掉会破坏独显驱动所需的运行环境。

## 三、1401 安装器会改写 config

安装 / 升级 1401 驱动时，安装器会自动改写引导介质上的 `config.plist`：

- `boot-args`（按 `WANT_ARGS` 补齐）
- `Kernel > Block / com.apple.iokit.IONDRVSupport`
- `Misc > Boot / HideAuxiliary`
- 替换 `OC/Tools/NullMothSafe.efi`

它改写前会留 `config.plist.before-1401-<时间>` 备份。**每次升级驱动后都要重新核对 config 指纹**，
确认 `-nodisplaysleepDC6`、`-allow3d -disablegfxfirmware` 与 1401 的全套参数都还在。
本机 14 版的状态是：`IONDRVSupport` 条目禁用、`HideAuxiliary=False`、`ExposeSensitiveData=3`（不显示 `REL-` 版本号）。

## 四、引导菜单相关（不在 boot-args 里）

| 项 | 位置 | 当前值 |
|---|---|---|
| 隐藏关机 / 重启 | `Misc > Boot > PickerAttributes` 的 `0x40` 位 | 未设置（保留按钮） |
| 隐藏主题图标 | `PickerAttributes` 的 `0x08` 位 | 未设置 |
| 指针控制 | `PickerAttributes` 的 `0x10` 位 | 已置位（当前 `PickerAttributes = 145` = `0x91`） |
| `REL-xxx` 版本号 | `Misc > Security > ExposeSensitiveData` 的 `0x04` 位 | 未设置（`ExposeSensitiveData = 3`） |
