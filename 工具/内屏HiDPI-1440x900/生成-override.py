#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成内屏显示 override（BOE 0x09E5:0x0A1F / 2560x1600）
模板参照苹果 13" MacBook Pro（DisplayVendorID-610/DisplayProductID-a040，同为 2560x1600 面板）。

关键点：大于面板原生的 HiDPI 模式（本例 2880x1800 = 逻辑 1440x900）
必须写成 flags=9 + 第四字段 0x00A00000（scaled），
写成 flags=1 + 0x00200000 会被系统当成非法条目整条丢弃。
"""
import plistlib, struct, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-9e5/DisplayProductID-a1f"
# 默认写到脚本同目录，不覆盖发布包里已验证的 DisplayProductID-a1f。
# 也可传入输出路径：python3 生成-override.py /path/to/out
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "DisplayProductID-a1f.generated")

src = plistlib.load(open(SRC, "rb"))
edid = src["IODisplayEDID"]
assert len(edid) == 128, len(edid)
ppmm = src.get("target-default-ppmm", 10.0699301)

HI = 0x00200000   # 面板原生以内的 2x
SC = 0x00A00000   # 超过面板原生、由 GPU 缩小输出（scaled）

def e9(w, h):                 # 9 字节：可用的帧缓冲尺寸清单
    return struct.pack(">IIB", w, h, 0)
def e16(w, h, flags, extra):  # 16 字节：带 HiDPI / scaled 语义
    return struct.pack(">IIII", w, h, flags, extra)
def e12(w, h):                # 12 字节：普通 1x 模式
    return struct.pack(">III", w, h, 1)

fb_sizes = [3360, 3200, 2880, 2560, 2048]          # 宽
scaled = [(3360, 2100), (3200, 2000), (2880, 1800)]  # 1680x1050 / 1600x1000 / 1440x900
hidpi_native = [(2560, 1600), (2048, 1280), (1920, 1200)]
flat = [(2560, 1600), (2048, 1280), (1920, 1200), (1680, 1050), (1440, 900),
        (1280, 800), (1152, 720), (1024, 768), (1024, 640), (800, 600),
        (800, 500), (640, 480)]

entries = []
entries += [e9(w, int(round(w * 0.625))) for w in fb_sizes]
entries += [e16(w, h, 1, HI) for w, h in hidpi_native]
entries += [e12(w, h) for w, h in flat]
entries += [e16(w, h, 9, SC) for w, h in scaled]

new = {
    "DisplayVendorID": 2533,
    "DisplayProductID": 2591,
    "DisplayProductName": "Color LCD",
    "IODisplayEDID": edid,
    "target-default-ppmm": ppmm,
    "scale-resolutions": entries,
}

with open(OUT, "wb") as f:
    plistlib.dump(new, f, fmt=plistlib.FMT_BINARY)

print("写入:", OUT)
print("条目数:", len(entries), " 大小:", os.path.getsize(OUT), "B")
print("EDID 保留:", len(edid), "B  ppmm:", ppmm)
