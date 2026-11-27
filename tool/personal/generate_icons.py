#!/usr/bin/env python3
"""生成「记流水账」的启动图标资源。

设计：深海军蓝底 + 蓝色水滴（尖头朝上）+ 白色人民币符号。
图形用 100×100 的坐标系手写，与 Android 矢量图（ic_launcher_foreground.xml）
共用同一套路径数据，避免"PNG 和矢量长得不一样"。

用法：
    python tool/personal/generate_icons.py

产物：
    android/app/src/main/res/mipmap-*/ic_launcher.png   旧版启动器图标（带圆角）
    ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png  iOS 全尺寸（正方形、无透明）
    dist/icon-design/preview-1024.png                   评审用大图
"""

import json
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

BG = (0x0C, 0x44, 0x7C)
DROP = (0x37, 0x8A, 0xDD)
FG = (0xFF, 0xFF, 0xFF)

SS = 4  # 超采样倍数
DROP_PATH = "M50 6C50 6 72 34 78 54A30 30 0 1 1 22 54C28 34 50 6 50 6Z"
YUAN_STROKE = 5.6


def _cubic(p0, p1, p2, p3, steps=80):
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        out.append((x, y))
    return out


def drop_points(steps=140):
    """复刻 DROP_PATH：上尖点 → 右切线 → 底部圆弧 → 左切线 → 回到尖点。"""
    pts = []

    # 1) 尖点(50,6) 到右切点(78,54)，控制点 (50,6) (72,34)
    pts += _cubic((50, 6), (50, 6), (72, 34), (78, 54), steps)

    # 2) 以 (50,64) 为心、半径 30，从右切点经底部扫到左切点
    cx, cy, r = 50.0, 64.0, 30.0
    a0 = math.radians(-19.65)
    a1 = math.radians(180 + 19.65)
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))

    # 3) 左切点(22,54) 回到尖点(50,6)，控制点 (28,34) (50,6)
    pts += _cubic((22, 54), (28, 34), (50, 6), (50, 6), steps)
    return pts


def _scaled(pts, size, off=0.0, span=100.0):
    k = (size - 2 * off) / span
    return [(off + x * k, off + y * k) for x, y in pts]


def _draw_yuan(d, size, color, off=0.0, span=100.0):
    k = (size - 2 * off) / span
    w = max(1, round(YUAN_STROKE * k))

    def P(x, y):
        return (off + x * k, off + y * k)

    d.line([P(39, 46), P(50, 58)], fill=color, width=w)
    d.line([P(61, 46), P(50, 58)], fill=color, width=w)
    d.line([P(50, 57), P(50, 78)], fill=color, width=w)
    for y in (60, 67):
        d.line([P(36, y), P(64, y)], fill=color, width=w)


def render(size, rounded=True, background=True):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if background:
        if rounded:
            radius = big * 0.225
            d.rounded_rectangle([0, 0, big - 1, big - 1], radius=radius, fill=BG + (255,))
        else:
            d.rectangle([0, 0, big - 1, big - 1], fill=BG + (255,))

    # 水滴占画布 62%，居中
    off = big * 0.19
    d.polygon(_scaled(drop_points(), big, off), fill=DROP + (255,))
    _draw_yuan(d, big, FG + (255,), off)

    return img.resize((size, size), Image.LANCZOS)


def save(img, path, rgb=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if rgb:
        flat = Image.new("RGB", img.size, BG)
        flat.paste(img, mask=img.split()[3])
        flat.save(path, "PNG", optimize=True)
    else:
        img.save(path, "PNG", optimize=True)


def main():
    # Android 旧版启动器图标（圆角，透明角）
    for bucket, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                         ("xxhdpi", 144), ("xxxhdpi", 192)]:
        p = os.path.join(ROOT, "android/app/src/main/res",
                         f"mipmap-{bucket}", "ic_launcher.png")
        save(render(size), p)
        print("android", bucket, size)

    # iOS：正方形、无透明通道（App Store 会拒绝带 alpha 的图标）
    icon_dir = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    meta = json.load(open(os.path.join(icon_dir, "Contents.json"), encoding="utf-8"))
    done = set()
    for item in meta["images"]:
        fn = item.get("filename")
        if not fn or fn in done:
            continue
        done.add(fn)
        base = float(item["size"].split("x")[0])
        scale = int(item["scale"].rstrip("x"))
        px = round(base * scale)
        save(render(px, rounded=False, background=True),
             os.path.join(icon_dir, fn), rgb=True)
        print("ios", fn, px)

    preview = os.path.join(ROOT, "dist/icon-design/preview-1024.png")
    save(render(1024), preview)
    print("preview", preview)


if __name__ == "__main__":
    main()
