#!/usr/bin/env python3
"""生成 HClash 应用图标（开发脚本，可复现）。

用法： python scripts/gen_icon.py
输出： AppScope/resources/base/media/app_icon.png
      entry/src/main/resources/base/media/app_icon.png
"""
import math
import os

from PIL import Image, ImageDraw

SIZE = 512
RADIUS = 96


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 背景：深色圆角矩形 + 蓝色渐变斜纹
    dark = (13, 17, 23, 255)       # #0D1117
    blue1 = (59, 130, 246, 255)    # #3B82F6
    blue2 = (96, 165, 250, 255)    # #60A5FA
    draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=RADIUS, fill=dark)

    # 圆形渐变光晕（左下 → 右上）
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for i in range(120):
        t = i / 120.0
        r = int(230 * (1 - t) + 20)
        col = lerp(blue2, blue1, t)
        cx, cy = int(SIZE * 0.62), int(SIZE * 0.38)
        gdraw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (int(10 * (1 - t)),))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # 中央"闪电"图形（Clash 家族的标志性意象）
    bolt = [
        (SIZE * 0.56, SIZE * 0.14),
        (SIZE * 0.30, SIZE * 0.55),
        (SIZE * 0.47, SIZE * 0.55),
        (SIZE * 0.42, SIZE * 0.86),
        (SIZE * 0.72, SIZE * 0.43),
        (SIZE * 0.53, SIZE * 0.43),
    ]
    bolt = [(int(x), int(y)) for x, y in bolt]
    draw.polygon(bolt, fill=(230, 237, 243, 255))

    # 闪电描边高光
    draw.line(bolt + [bolt[0]], fill=blue2, width=3, joint="curve")

    out_dirs = [
        os.path.join(os.path.dirname(__file__), "..", "AppScope", "resources", "base", "media"),
        os.path.join(os.path.dirname(__file__), "..", "entry", "src", "main", "resources", "base", "media"),
    ]
    for d in out_dirs:
        os.makedirs(d, exist_ok=True)
        path = os.path.abspath(os.path.join(d, "app_icon.png"))
        img.save(path)
        print(f"written: {path}")


if __name__ == "__main__":
    main()
