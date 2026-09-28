#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从官方 Antigravity 图标重新生成「深色底板」变体 icns。

原理
----
1. 从官方 icon.icns 解出最大的一档（512×512）作为基准图。
2. 官方图标 = 纯白圆角方块 + 彩虹渐变 A 字形。
   用「与纯白 (255,255,255) 的欧氏距离」把 A 字形从白底板里抠出来：
       d <= NEAR(18)  → 视为底板，alpha 0
       d >= FAR(95)   → 视为字形，alpha 255
       中间线性过渡  → 抗锯齿边缘
   （不要用饱和度判据：彩虹 A 顶部有一圈接近白的浅色，会被漏判。）
3. 用原图的 alpha 通道当「圆角方块」形状遮罩，铺上新底板（纯色 / 渐变），
   再把抠出来的 A 字形按 alpha 叠回去。
4. 缩放到各尺寸档位，用 iconutil 打包成 .icns。

用法
----
    python3 scripts/make_icns.py                 # 生成全部变体到 icons/
    python3 scripts/make_icns.py --out /tmp/gen  # 指定输出目录
    python3 scripts/make_icns.py --only G A      # 只生成指定变体
    python3 scripts/make_icns.py --list          # 列出变体

依赖：Pillow（pip install pillow），以及 macOS 自带的 iconutil / sips。
"""

import argparse
import math
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_SOURCE = os.path.join(ROOT, "original-icon.icns")
APP_ICON = "/Applications/Antigravity.app/Contents/Resources/icon.icns"

# 字形提取阈值（与纯白的欧氏距离）
NEAR, FAR = 18.0, 95.0

# 官方方块在 512 画布里的范围（alpha 不为 0 的 bbox）
SQUARE_TOP, SQUARE_BOT = 47, 466

# icns 需要的所有档位：(逻辑尺寸, 像素尺寸, iconset 文件名)
SLOTS = [
    (16, 16, "icon_16x16.png"),
    (16, 32, "icon_16x16@2x.png"),
    (32, 32, "icon_32x32.png"),
    (32, 64, "icon_32x32@2x.png"),
    (128, 128, "icon_128x128.png"),
    (128, 256, "icon_128x128@2x.png"),
    (256, 256, "icon_256x256.png"),
    (256, 512, "icon_256x256@2x.png"),
    (512, 512, "icon_512x512.png"),
    (512, 1024, "icon_512x512@2x.png"),
]

# ---------------- 变体定义 ----------------
# kind: solid（纯色）/ gradient（垂直渐变）/ glow（纯色 + 字形光晕）
VARIANTS = {
    "G": dict(
        kind="gradient",
        name="G-Gemini.icns",
        top=(0x21, 0x21, 0x21),
        bot=(0x0F, 0x0F, 0x0F),
        desc="Gemini 同款：#212121 → #0F0F0F 渐变（推荐）",
    ),
    "A": dict(
        kind="solid", name="A-炭黑1C1C1E.icns", color=(0x1C, 0x1C, 0x1E),
        desc="炭黑 #1C1C1E（macOS 原生深色标准色）",
    ),
    "B": dict(
        kind="solid", name="B-深灰2B2B2E.icns", color=(0x2B, 0x2B, 0x2E),
        desc="深灰 #2B2B2E（方块边界最清晰）",
    ),
    "C": dict(
        kind="solid", name="C-Google202124.icns", color=(0x20, 0x21, 0x24),
        desc="Google 品牌深灰 #202124",
    ),
    "D": dict(
        kind="glow", name="D-近黑光晕.icns", color=(0x10, 0x10, 0x12),
        glow_radius=18, glow_strength=0.85,
        desc="近黑 #101012 + A 字形彩色光晕",
    ),
}


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def load_base(source):
    """从 icns 解出最大的一档，返回 512×512 RGBA。"""
    if not os.path.exists(source):
        if os.path.exists(APP_ICON):
            print(f"→ 未找到 {source}，改用本机的 {APP_ICON}")
            source = APP_ICON
        else:
            sys.exit(f"✗ 找不到源图标：{source}\n  也没有安装 Antigravity（{APP_ICON} 不存在）")

    tmp = tempfile.mkdtemp(prefix="agicon-")
    try:
        iconset = os.path.join(tmp, "src.iconset")
        run(["/usr/bin/iconutil", "-c", "iconset", source, "-o", iconset])
        cands = []
        for f in os.listdir(iconset):
            if f.endswith(".png"):
                im = Image.open(os.path.join(iconset, f))
                cands.append((im.size[0], os.path.join(iconset, f)))
        if not cands:
            sys.exit("✗ 源 icns 里没有任何 png 档位")
        cands.sort()
        path = cands[-1][1]
        print(f"→ 基准图: {os.path.basename(path)}")
        return Image.open(path).convert("RGBA")
    finally:
        pass  # 临时目录留给调用方清理也无妨；体积很小


def extract_glyph(base):
    """从白底板上抠出 A 字形，返回 RGBA（底板处 alpha=0）。"""
    w, h = base.size
    glyph = Image.new("RGBA", (w, h))
    sp, gp = base.load(), glyph.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            d = math.sqrt((255 - r) ** 2 + (255 - g) ** 2 + (255 - b) ** 2)
            if d <= NEAR:
                continue  # 白底板 → 透明
            v = 255 if d >= FAR else int((d - NEAR) / (FAR - NEAR) * 255)
            gp[x, y] = (r, g, b, v)
    return glyph


def make_plate(kind, size, spec):
    """生成底板（整幅 RGBA，圆角外的 alpha 由调用方裁）。"""
    w, h = size
    if kind == "solid":
        return Image.new("RGBA", (w, h), spec["color"] + (255,))
    if kind == "gradient":
        top, bot = spec["top"], spec["bot"]
        plate = Image.new("RGBA", (w, h))
        pp = plate.load()
        y0, y1 = SQUARE_TOP, SQUARE_BOT
        span = max(1, y1 - y0)
        for y in range(h):
            t = 0.0 if y <= y0 else (1.0 if y >= y1 else (y - y0) / span)
            c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
            for x in range(w):
                pp[x, y] = c + (255,)
        return plate
    if kind == "glow":
        return Image.new("RGBA", (w, h), spec["color"] + (255,))
    raise ValueError(kind)


def composite(base, glyph, spec):
    """合成一个变体的 512×512 图。"""
    shape = base.split()[3]                      # 圆角方块 alpha
    plate = make_plate(spec["kind"], base.size, spec)

    if spec["kind"] == "glow":
        # 把字形模糊后当作光晕，压在底板上
        glow = glyph.filter(ImageFilter.GaussianBlur(spec.get("glow_radius", 18)))
        k = spec.get("glow_strength", 0.85)
        gr, gg, gb, ga = glow.split()
        ga = ga.point(lambda v: int(v * k))
        plate = Image.composite(Image.merge("RGBA", (gr, gg, gb, ga)), plate, ga)

    out = Image.new("RGBA", base.size)
    out.paste(plate, (0, 0), shape)              # 底板裁成圆角方块
    out = Image.alpha_composite(out, glyph)      # 叠回 A 字形
    return out


def write_icns(img, dest):
    tmp = tempfile.mkdtemp(prefix="agicon-out-")
    try:
        iconset = os.path.join(tmp, "out.iconset")
        os.makedirs(iconset)
        for _, px, fname in SLOTS:
            img.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, fname))
        run(["/usr/bin/iconutil", "-c", "icns", iconset, "-o", dest])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description="生成 Antigravity 深色图标变体")
    ap.add_argument("--source", default=DEFAULT_SOURCE, help="官方 icon.icns 路径")
    ap.add_argument("--out", default=os.path.join(ROOT, "icons"), help="输出目录")
    ap.add_argument("--only", nargs="*", help="只生成指定变体（如 G A）")
    ap.add_argument("--list", action="store_true", help="列出变体并退出")
    args = ap.parse_args()

    if args.list:
        for k, v in VARIANTS.items():
            print(f"  {k}  {v['name']:24s} {v['desc']}")
        return

    keys = [k.upper() for k in args.only] if args.only else list(VARIANTS)
    bad = [k for k in keys if k not in VARIANTS]
    if bad:
        sys.exit(f"✗ 未知变体: {bad}，可用: {list(VARIANTS)}")

    base = load_base(args.source)
    print("→ 提取 A 字形（逐像素，约几秒）...")
    glyph = extract_glyph(base)

    os.makedirs(args.out, exist_ok=True)
    for k in keys:
        spec = VARIANTS[k]
        dest = os.path.join(args.out, spec["name"])
        print(f"→ 生成 {k}: {spec['name']}")
        write_icns(composite(base, glyph, spec), dest)
        print(f"    ✓ {os.path.getsize(dest):,} 字节")
    print("\n完成。用 ./apply-icon.sh <变体> 应用。")


if __name__ == "__main__":
    main()
