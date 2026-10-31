# MECHREVO GM6AR57C · OpenCore EFI（混合模式 · 核显加速可用）

**i7-12800HX · RTX 4070 Laptop · Intel UHD（ADL-HX）· macOS Sequoia 15.8.2**

> 这份 EFI 让内屏走**核显**、独显同时可用（BIOS 设为混合模式 / MUX Hybrid）。
> 内屏 2560×1600 HiDPI 正常、亮度可调；独显 Metal 3 正常。
> **核显加速已放行**（控制中心、通知中心、小部件均正常），
> **第三方播放器硬解可用**（走 NVIDIA 解码，详见第 4.5 节）。
> **本版（10）修掉了长期存在的"显示器休眠后唤醒黑屏"** —— 熄屏时既不再切断面板/AUX 供电，
> 也不再让 DC6/DC9 门控显示电源井；实测 43 / 60 / 89 / 122 秒熄屏后唤醒全部正常（详见第 4.8 节）。
> 本版对应 `EFI-版本/10`，相比 09 版换两个文件：`OC/Kexts/WhateverXe.kext`（黑屏修复）与 `OC/config.plist`（引导项微调，与本修复无关）。

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
| 屏幕 | 2560×1600，面板原生 165Hz，BOE（EDID `09e5:0a1f`），eDP。**混合模式下只能跑 60Hz**（EDID 里唯一 DTD 就是 60Hz，Apple TGL 帧缓冲只按 DTD 建模式） |
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
| **Catalyst（UIKit）应用** | FaceTime / 天气 / 股市 / 查找 在这台机器上开不出窗口（主线程卡在 `NSRemoteView`，等不到远程视图服务），与显卡、相机、权限都无关 |
| **显示器休眠后唤醒黑屏** | **10 版已修复**（见 4.8）。09 及以前：熄屏一段时间后再唤醒会黑掉且不能自恢复，只能长按电源。10 版连续 4 轮 43–122 秒熄屏唤醒均正常 |
| 长时间关屏-开屏剧烈抖动 | 10-31 05:50 出现一次核显 hang（`MI_WAIT_FOR_EVENT` 永不返回）+ WindowServer watchdog 杀进程。触发条件是屏幕关掉 4.5 小时后被反复"申请/释放防休眠断言"抖动唤醒。**与上面的唤醒黑屏不是同一个问题，10 版未专门验证**；长期无人值守时仍建议 `sudo pmset -a displaysleep 0` |
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
- 版本：**2.6.5**（NVRM / NVAccel / NVRMFB / NVRMAGDC / NVMTL），装到 `/Library/Extensions` 并重建 AuxKC；
- 装完在「系统设置 → 隐私与安全性」允许扩展，再重启；
- 本 EFI 已包含它需要的 `csr-active-config=0x0A43` 与 `nvfb=1 nvaccel=1 …`；
- **注意 `Kernel > Block / com.apple.iokit.IONDRVSupport`**：07/08 里这条是**启用**的（防 IONDRVFramebuffer 抢占 index 0），
  但 2.6.5 的安装器会把它改成**禁用**，同时把 `Misc > Boot / HideAuxiliary` 改成 `false`、换上新的 `OC/Tools/NullMothSafe.efi`。
  09 版就是安装器改完后的状态，开机正常，两处改动可以保留。

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
sudo bash 脚本/3-状态确认.sh             # 检查补丁 + 黑屏修复三个钩子是否都在位
bash    脚本/5-熄屏唤醒测试.command      # 熄屏 60 秒 → 唤醒 → 取证，确认唤醒不黑屏
```

### 4.6 有线网卡（可选，官方）

YT6801 走用户态驱动：<https://github.com/MiniYv/yt6801-for-macOS>，装完在系统设置里批准。

### 4.7 播放器建议

- **IINA**：<https://iina.io>，本方案下无需任何额外设置，硬解自动走 NVIDIA；
- 验证硬解：播放时看活动监视器 CPU（1080p 硬解约 2–5%），
  或运行 `脚本/3-状态确认.sh`（会检查 IINA 是否加载 `libnvdec`）。

### 4.8 显示器休眠唤醒黑屏（10 版已修复）

**症状**（09 及以前）：屏幕熄灭（自动或 `pmset displaysleepnow`）之后再唤醒，**屏幕永久黑掉**，系统其实还在跑（远程还能连上、键鼠有响应）。
`displaypolicyd` 日志稳定报 `LinkUpdate: 1.0 event: TrainingError [b]`，之后不再有 `FB AGDC state FB[0] - ON`；内核日志里伴随
`DBUF 2 power up timeout` 与 `Phase 1 of link training failed`。冷启动/重启后的首次点亮是正常的，**只有整机断电重启能恢复**。
实测统计：约 45% 的唤醒会失败，熄屏 85 秒 / 131 秒这类长熄屏**全部**失败。

**根因是两层叠在一起**（完整逆向过程见 `文档/黑屏唤醒修复说明.md`）：

1. **面板供电层**：熄屏时驱动调 `AppleIntelFramebufferController::hwSetPanelPower(0)`，**真的切断 eDP 面板/AUX 供电**；
   唤醒时重新上电并**必须重新训练 eDP 链路**——本机这块第三方面板的重新训练**确定性失败**，
   `LightUpEDP` 却照常配置 pipe，于是"管道在跑、链路没通" → 全黑。
2. **DC 门控层**：即使让面板保持供电（只修第 1 层的版本实测仍会在约 20 秒短熄屏后黑掉），
   `AppleIntelFramebuffer::setFramebufferPowerState` 在 `Wake → Doze` 结尾会调 `setDCState(true)`，
   只要**任意一个** framebuffer 状态非 0 就武装 **DC6/DC9**，把显示电源井 / DBUF / eDP AUX 一起门控掉。
   下一次 `Doze → Wake` 依赖 DC 退出，而这条退出在 15.8.2 上是**概率性失败**——一旦失败就是
   `DBUF 2 power up timeout` → 随后每一条 AUX 事务超时 → 训练失败 → AGDC 把显示拉下线，只能冷启动。

**10 版的修法**（WhateverXe 里四个动作，不涉及 config、不需要 boot-args）：

| # | 钩子 | 作用 |
|---|---|---|
| 1 | `hwSetPanelPower` | `state==2`（上电）转发原生；其余状态直接返回成功**不动硬件** → 熄屏不再切面板/AUX 供电，唤醒无需重训链路 |
| 2 | `setFramebufferPowerState` | 诊断：记录每个 FB 的新旧状态、调用者，Doze 转换后采样 `0x45008/0x44FE8/0x45404/0x46070/0x42000` |
| 3 | `setDCState` | **DC 守卫**：当参数为 `true` 且**正在切换的那个 FB** 的新状态是 1（Doze）时，跳过 DC6/DC9 武装 → 电源井/DBUF/AUX 保持可访问 |
| 4 | 训练重试循环 | 停用（原先失败重试 3 次要烧 ~30 秒，逼近 WindowServer 40 秒 watchdog，会连锁杀掉 WindowServer） |

> 钩子 3 的条件必须按"当前正在转换的那个 FB"判定，不能要求"所有 FB 都是 Doze"——
> 本机控制器有 3 个 framebuffer，只有内屏 FB0 会熄屏，另外两个始终是亮屏态。
> 早期按"全部 FB"写的版本守卫**永不命中**，这是踩过的坑。

效果：熄屏时 pipe 照关、背光照灭（观感不变），但显示电源井 / DBUF / eDP AUX 保持供电；唤醒不再依赖那条会失败的 DC 退出路径。

**怎么确认它在生效**（重要——源码里有函数 ≠ 钩子装上了，本次修复过程中有三处"修复"其实是死代码）：

```bash
ioreg -n Root -l -w0 | tr ',' '\n' | \
  grep -E "WhateverXePanelPowerHooked|TGLWEXFBStateRouted|TGLWEXDozeDCGuardReady"
# 三项都必须是 Yes
```

或者直接跑 `bash 脚本/3-状态确认.sh`（会一并打印 DC 守卫累计拦截次数）。

**实测**（14:26 冷启动加载 v3.1，14:45–14:52 连续 4 轮）：

| 熄屏时长 | 结果 |
|---|---|
| 60 s / 89 s / 122 s / 43 s | ✅ 均正常点亮，`TrainingError = 0`、`LinkUpdate = 0`、无 `DBUF … timeout` |

其中 122 秒落在历史 100% 失败区间，43 秒那轮是系统 5 分钟空闲计时器自然触发的；
DC 守卫拦截计数与熄屏次数 **1:1** 对应（0 → 4）。

完整判读方法与注意事项见 `文档/黑屏唤醒修复说明.md` 第七节；一键复测用 `脚本/5-熄屏唤醒测试.command`。

**遗留（不是同一个问题）**：10-31 05:50 曾出现一次核显 hang（`gpuRestart`，`IPEHR=0x03800000` 即 `MI_WAIT_FOR_EVENT`）
→ WindowServer 40 秒无 checkin 被 watchdog 杀掉。触发条件是屏幕关掉 4.5 小时后被**反复"申请/释放防休眠断言"抖动唤醒**。
长期无人值守（串流、下载）时仍建议 `sudo pmset -a displaysleep 0`，把这类抖动窗口掐掉。
`boot-args` 里的 `-nopsr` 仍然保留（关 PSR 无害）。

## 5. 本发布包内容

```
EFI/                               OpenCore 1.0.8 完整 EFI（已含全部 kext，与发布标签 v10 一致，三码已脱敏）
RELEASE-NOTES-2026-10-31-v10.md    10 版发布说明（相对 09 的差异 + 黑屏修复）
驱动/WhateverXe.kext               自编译版：背光门禁放宽 + 15.8.2 准入修复 + 黑屏唤醒修复
驱动/SMCNvidiaGPU-源码与kext       传感器插件本地适配源码（绑定表脚本 + 已知可用构建）
脚本/1-UI修复补丁.command           修控制中心/时钟/小部件崩溃
脚本/2-视频硬解修复.command         修播放器闪退、统一硬解到 NVIDIA
脚本/3-状态确认.sh                 一键检查补丁状态 / 黑屏修复三个钩子 / 是否硬解 / 近期崩溃
脚本/4-回滚.command                撤销两个补丁
脚本/5-熄屏唤醒测试.command         熄屏→唤醒→三处取证，验证黑屏修复是否真在生效
文档/根因确诊与修复说明.md          两处 GPU 补丁的完整逆向过程
文档/黑屏唤醒修复说明.md            显示器休眠唤醒黑屏的根因与修复（10 版，含被证伪的 6 种尝试）
```

**关于 `驱动/SMCNvidiaGPU-源码与kext`**：这份源码包里的绑定表是按 NullMoth **2.6.2 / 2.6.3** 生成的
（1.3.2 / 1.3.3），而 EFI 里实际放的是按 **2.6.4** 重编的 **1.3.4**。驱动升到 2.6.5 后如果传感器读不到，
用目录里的 `kext/build.sh` + `kext/nvrm_bindings.py` 对着当前 `/Library/Extensions/NVRM.kext` 重跑一遍即可
（`nvrm_bindings.py` 现场解析驱动、生成 `nvrm_bindings.h`，**驱动一变必须重编**）。

**关于 `WhateverXe.kext`**：本包内这份是从 0.6.1 源码自行编译的修改版（二进制 SHA-256 前缀 `7118672f`），改了四处——
① 放宽 ADL-S/HX 内屏背光的写入门禁（原版要求 fuse bit24，本机为 0，亮度写不进去）；
② 加速器准入校验改为解析 rel32 目标符号（15.8.2 把 `_IOProtectCacheMode` 移动了 0x30 字节，
原版写死绝对位移会失配，导致准入 19/20）；
③ **hook `hwSetPanelPower`：显示器休眠时不真正切断面板/AUX 供电（除上电外的状态一律 no-op）**，
并停用了原先"训练失败重试 3 次"的循环（那会阻塞 ~30s，逼近 WindowServer watchdog）；
④ **DC 守卫：`setDCState(true)` 在"正在熄屏的那个 FB 进入 Doze"时不再武装 DC6/DC9**，
让显示电源井 / DBUF / eDP AUX 在熄屏期间保持可访问——
③+④ 合起来才是 10 版修掉"显示器休眠唤醒黑屏"的完整方案（只做 ③ 仍会在短熄屏后概率性黑屏）。

> ⚠️ 判断 ③④ 是否生效，必须看**运行时 IORegistry**（源码里有函数不代表装上了，本次就有三处"修复"是死代码）：
> `ioreg -n Root -l -w0 | tr ',' '\n' | grep -E "WhateverXePanelPowerHooked|TGLWEXDozeDCGuardReady"` 必须都是 `Yes`。
> 重装 / 重编 WhateverXe 后要重新确认。

## 6. 版本信息

| 项目 | 值 |
|---|---|
| macOS | 15.8.2（24H232） |
| OpenCore | 1.0.8（`REL-108-2026-09-27`） |
| 仿冒机型 | `MacBookPro16,2` |
| SIP | `csr-active-config = 0x0A43` |
| boot-args | `keepsyms=1 ipc_control_port_options=0 revpatch=auto,sbvmm,asset,cpuname nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth gfxrst=4 nvrmacpibl=1 -vi2c-force-polling amfi_get_out_of_my_way=0x1 amfi=0x80 dk=0x8001 -allow3d -disablegfxfirmware -nopsr` |
| WhateverXe.kext | 0.6.1（本地修改版：15.8.2 准入修复 + **黑屏唤醒修复（面板常供电 + DC 守卫）**，`7118672f…`） |
| config.plist | SHA-256 前缀 `832e6cb9`（本发布包脱敏后的值；原始 EFI 为 `cf1022c4…`，差异仅三码占位） |
| WhateverXe Graphics | 0.3.2 或更新 |
| NullMoth | 2.6.5 |
| SMCNvidiaGPU | 1.3.4 |

**启用的关键 kext**：Lilu 1.7.3、WhateverXe 0.6.1（本地修改版）、AMFIPass 1.4.1 Mod、
VirtualSMC 1.3.8、SMCNvidiaGPU 1.3.4、AppleALC、AirportItlwm、IntelBluetoothFirmware、
VoodooI2C/VoodooPS2、SMCBatteryManager、CpuTopologyRebuild、CPUFriend。

## 7. 出问题怎么退

| 状况 | 处理 |
|---|---|
| 内屏黑 / 起不来 | Windows 下把 U 盘 `EFI` 改名，换回自己的备份 EFI |
| 关屏回来后黑屏、键鼠无响应 | 长按电源 10 秒冷启动（普通重启救不回来）。然后跑 `bash 脚本/3-状态确认.sh`，确认三个钩子（`WhateverXePanelPowerHooked` / `TGLWEXFBStateRouted` / `TGLWEXDozeDCGuardReady`）都是 `Yes`；不是就换回本包 `驱动/WhateverXe.kext`。长时间无人值守再 `sudo pmset -a displaysleep 0` |
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
