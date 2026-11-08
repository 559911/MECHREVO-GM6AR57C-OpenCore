#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WhateverXe 0.8.0「两补丁」候选版。

与三补丁版的差别：删掉 P3（Doze 期间不武装 DC6/DC9 的本地钩子），
改用苹果帧缓冲驱动自带的 -nodisplaysleepDC6 启动参数。
该参数在 AppleIntelFramebufferController::start 里解析，把 +0xC29 置 0；
setDCState 在装载 DC6 前 cmpb $0,0xc29 命中即跳过，覆盖面与 P3 相同。

保留：
  P1  ADL-S 内屏背光去掉 FUSE bit24 门禁（上游 0.8.0 未修）
  P2  原生 hwSetPanelPower 非上电状态 no-op（上游无对应实现）

每条补丁的锚点都要求全文恰好出现一次，否则直接报错退出。
"""

import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
CPP = os.path.join(ROOT, "src-2补丁", "WhateverXe", "kern_xe.cpp")
HPP = os.path.join(ROOT, "src-2补丁", "WhateverXe", "kern_xe.hpp")


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def save(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def replace_once(text, old, new, tag):
    n = text.count(old)
    if n != 1:
        print("[失败] %s 的锚点出现 %d 次（要求恰好 1 次）" % (tag, n))
        sys.exit(1)
    print("[锚点通过] %s  唯一" % tag)
    return text.replace(old, new, 1)


def insert_after(text, anchor, block, tag):
    n = text.count(anchor)
    if n != 1:
        print("[失败] %s 的锚点出现 %d 次（要求恰好 1 次）" % (tag, n))
        sys.exit(1)
    print("[锚点通过] %s  唯一" % tag)
    return text.replace(anchor, anchor + block, 1)


cpp = load(CPP)
hpp = load(HPP)

# ---------------------------------------------------------------- P1-a
P1A_OLD = """ const auto wells=read(0x45404),fuse=read(0x42000);
 if(wells!=~0U && fuse!=~0U && (wells&1) && (fuse&0x01000000)) {
  const auto period=read(0xC8254),control=read(0xC8250);
"""
P1A_NEW = """ const auto wells=read(0x45404),fuse=read(0x42000);
 // 本机 FUSE(0x42000) 没有 bit24，原生门禁会永远拒绝捕获 PWM。
 // 显示电源井已上电(wells&1)即已具备访问条件，去掉 fuse 位要求。
 if(wells!=~0U && (wells&1)) {
  const auto period=read(0xC8254),control=read(0xC8250);
"""
cpp = replace_once(cpp, P1A_OLD, P1A_NEW, "P1-a adlsCapturePanelPWM 的 FUSE 门禁")

# ---------------------------------------------------------------- P1-b
P1B_OLD = """ void *access,*power;uint32_t duty;
 if(!adlsCapturePanelPWM(controller) || !adlsPanelPWMTarget(controller,access,power) ||
    !s->adlsPanelPWM.duty(brightness,duty))return kIOReturnNotReady;
 auto &f=s->tglTCNativeFunctions;f.getPG(power,1);
 const auto wells=FunctionCast(wrapTGLRegisterRead,s->orgTGLRegisterRead)(access,0x45404);
 const auto fuse=FunctionCast(wrapTGLRegisterRead,s->orgTGLRegisterRead)(access,0x42000);
 const bool ready=wells!=~0U && fuse!=~0U && (wells&1) && (fuse&0x01000000);
"""
P1B_NEW = """ void *access,*power;uint32_t duty;
 if(!adlsCapturePanelPWM(controller) || !adlsPanelPWMTarget(controller,access,power))return kIOReturnNotReady;
 const uint32_t b16=brightness>65535?65535:brightness;
 if(!s->adlsPanelPWM.duty(b16,duty))return kIOReturnNotReady;
 auto &f=s->tglTCNativeFunctions;f.getPG(power,1);
 const auto wells=FunctionCast(wrapTGLRegisterRead,s->orgTGLRegisterRead)(access,0x45404);
 const auto fuse=FunctionCast(wrapTGLRegisterRead,s->orgTGLRegisterRead)(access,0x42000);
 // 同上：本机 FUSE 无 bit24，只用电源井上电作为写寄存器门禁。
 const bool ready=wells!=~0U && (wells&1);
"""
cpp = replace_once(cpp, P1B_OLD, P1B_NEW, "P1-b wrapADLSPanelBacklight 的门禁与亮度夹取")

# ---------------------------------------------------------------- P2
P2_ANCHOR = " // DONOR_PANEL_PROPERTY_END\n"
P2_BLOCK = """			// 本机内屏走原生 hwSetPanelPower，不走 Display13 面板适配器
			// （adlnOutputWiring.panel=false，那条路是死代码）。
			// 熄屏时原生会真切掉 eDP 面板与 AUX 供电，唤醒必须重训链路，
			// 而这块第三方面板重训必失败 → 管道在跑、链路没通 → 全黑。
			// 只放行上电(2)，其余状态返回成功且不动硬件，把重训整条绕开。
			{
				const char *panelSymbol="__ZN31AppleIntelFramebufferController15hwSetPanelPowerEj";
				static const uint8_t panelEntry[]={0x55,0x48,0x89,0xe5,0x41,0x57,0x41,0x56,0x53,0x48,0x83,0xec,0x28,0x89,0xf3,0x49,0x89,0xff};
				const auto panelFn=patcher.solveSymbol<mach_vm_address_t>(index,panelSymbol,address,size);
				const bool panelKnown=size>0x48ABC && panelFn==address+0x48652 &&
					!memcmp(reinterpret_cast<const void *>(panelFn),panelEntry,sizeof(panelEntry));
				patcher.clearError();
				KernelPatcher::RouteRequest panelRoute(panelSymbol,wrapPlainPanelPower,orgPlainPanelPower);
				const bool panelRouted=panelKnown && patcher.routeMultipleShort(index,&panelRoute,1,address,size);
				patcher.clearError();
				IORegistryEntry::getRegistryRoot()->setProperty("WhateverXePanelPowerHooked",panelRouted);
			}
"""
cpp = insert_after(cpp, P2_ANCHOR, P2_BLOCK, "P2 面板供电 no-op 钩子的路由")

# ---------------------------------------------------------------- P2-b
# 钩子实现。注意：三补丁版里这段和 Doze 守卫写在同一个代码块里，
# 删 P3 时容易连带删掉，导致 wrapPlainPanelPower 只有声明没有定义（构建会报
# 'unresolved local implementation'）。这里单独成块。
P2B_ANCHOR = """	tglObserveEngine(power, 1, true, caller);
}

"""
P2B_BLOCK = """// 原生 hwSetPanelPower 的唯一实际执行路径（Display13 适配器在本机是死代码）。
// 上电(2)原样转发；熄屏(0)/Doze(1) 返回成功但不动硬件。
uint32_t XE::wrapPlainPanelPower(void *controller,uint32_t state) {
 auto s=callbackXE;
 if(!s || !s->orgPlainPanelPower)return 0xe00002c7U;
 uint32_t record[2]={state,0};
 if(state==2)record[1]=FunctionCast(wrapPlainPanelPower,s->orgPlainPanelPower)(controller,state);
 IORegistryEntry::getRegistryRoot()->setProperty("WhateverXePanelPowerCall",record,sizeof(record));
 return record[1];
}

"""
cpp = insert_after(cpp, P2B_ANCHOR, P2B_BLOCK, "P2-b 面板供电钩子实现")

# ---------------------------------------------------------------- hpp
H2_ANCHOR = " static uint32_t wrapDisplay13PanelPower(void *controller,uint32_t state);\n"
H2_BLOCK = """ mach_vm_address_t orgPlainPanelPower {};
 static uint32_t wrapPlainPanelPower(void *controller,uint32_t state);
"""
hpp = insert_after(hpp, H2_ANCHOR, H2_BLOCK, "hpp 原生面板供电钩子声明")

save(CPP, cpp)
save(HPP, hpp)

print("")
print("两补丁已写入：%s / %s" % (os.path.basename(CPP), os.path.basename(HPP)))
print("P3 已删除，依赖 boot-arg -nodisplaysleepDC6 替代。")
