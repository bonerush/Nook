#!/usr/bin/env python3
"""Generate the Nook app icon (a dark liquid-glass notch display).

Run from the repository root:
    python3 scripts/make-icon.py
"""

from __future__ import annotations

import math
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

FINAL = 1024
SS = 2
S = FINAL * SS
CENTER = S // 2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Resources")
ICONSET = os.path.join(RESOURCES, "Nook.iconset")


def rounded_mask(box, radius, size=S):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def rgba_box(image, box, radius, fill):
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=fill)
    return Image.alpha_composite(image, layer)


def soft_glow(image, shapes, color, blur):
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for box, radius in shapes:
        draw.rounded_rectangle(box, radius=radius, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(image, layer)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def main():
    os.makedirs(RESOURCES, exist_ok=True)

    # ---- base mask and shadow -------------------------------------------------
    outer_box = (144, 144, S - 144, S - 144)
    outer_radius = 470
    base_mask = rounded_mask(outer_box, outer_radius)

    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.putalpha(base_mask.filter(ImageFilter.GaussianBlur(58)))
    shadow = shadow.point(lambda v: int(v * 0.52))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (0, 22))

    # ---- glass body gradient --------------------------------------------------
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    diag = np.clip((xx / S) * 0.42 + (yy / S) * 0.58, 0, 1)

    top = np.array([43, 52, 68], dtype=np.float32)
    bottom = np.array([6, 7, 11], dtype=np.float32)
    rgb = top[None, None, :] * (1 - diag[..., None]) + bottom[None, None, :] * diag[..., None]

    def radial(cx, cy, sigma, color, strength):
        dist2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * sigma * sigma)
        falloff = np.exp(-dist2)[..., None]
        return np.array(color, dtype=np.float32)[None, None, :] * falloff * strength

    rgb += radial(390, 280, 670, (96, 145, 207), 0.44)
    rgb += radial(1620, 1680, 720, (238, 207, 156), 0.22)
    rgb += radial(1240, 260, 420, (140, 180, 228), 0.10)

    rng = np.random.default_rng(0x4E4F4F4B)
    grain = rng.normal(0, 3.6, (S, S, 1))
    rgb = np.clip(rgb + grain, 0, 255)

    alpha = np.asarray(base_mask, dtype=np.float32)[..., None] / 255.0
    body_arr = np.concatenate([rgb, alpha * 255], axis=2).astype(np.uint8)
    body = Image.fromarray(body_arr, "RGBA")
    canvas.alpha_composite(body)

    # ---- glass reflection and rim --------------------------------------------
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.ellipse(
        (-260, -420, 1480, 900),
        fill=(255, 255, 255, 18),
    )
    gd.ellipse(
        (600, -520, 2350, 620),
        fill=(178, 211, 255, 8),
    )
    gloss = gloss.filter(ImageFilter.GaussianBlur(120))
    gloss.putalpha(ImageChops.multiply(gloss.getchannel("A"), base_mask))
    canvas = Image.alpha_composite(canvas, gloss)

    inner_box = (outer_box[0] + 5, outer_box[1] + 5, outer_box[2] - 5, outer_box[3] - 5)
    inner_mask = rounded_mask(inner_box, outer_radius - 5)
    rim_mask = ImageChops.subtract(base_mask, inner_mask)

    rim_arr = np.zeros((S, S, 4), dtype=np.uint8)
    top_light = np.array([255, 252, 244], dtype=np.float32)
    cool = np.array([147, 186, 231], dtype=np.float32)
    warm = np.array([236, 206, 153], dtype=np.float32)
    t = np.clip((xx / S) * 0.55 + (yy / S) * 0.45, 0, 1)[..., None]
    rim_rgb = top_light[None, None, :] * (1 - t) + cool[None, None, :] * 0.35 + warm[None, None, :] * (t * 0.55)
    rim_rgb = np.clip(rim_rgb, 0, 255)
    rim_alpha = np.asarray(rim_mask, dtype=np.float32)[..., None] * 0.62
    rim_arr = np.concatenate([rim_rgb, rim_alpha], axis=2).astype(np.uint8)
    canvas.alpha_composite(Image.fromarray(rim_arr, "RGBA"))

    # A crisp top specular arc.
    spec = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spec)
    sd.arc(
        (outer_box[0] + 70, outer_box[1] + 43, outer_box[2] - 70, outer_box[1] + 450),
        start=200,
        end=340,
        fill=(255, 255, 255, 152),
        width=4,
    )
    spec = spec.filter(ImageFilter.GaussianBlur(4))
    spec.putalpha(ImageChops.multiply(spec.getchannel("A"), base_mask))
    canvas = Image.alpha_composite(canvas, spec)

    # ---- hardware notch -------------------------------------------------------
    content = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    notch_box = (CENTER - 300, 80, CENTER + 300, 306)
    notch_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    nd = ImageDraw.Draw(notch_layer)
    nd.rounded_rectangle(notch_box, radius=92, fill=(3, 4, 6, 255))
    # bottom lip
    nd.rounded_rectangle((CENTER - 300, 184, CENTER + 300, 312), radius=56, fill=(3, 4, 6, 255))
    content.alpha_composite(notch_layer)

    # camera lens
    ld = ImageDraw.Draw(content)
    ld.ellipse((CENTER - 24, 154, CENTER + 24, 202), fill=(11, 15, 22, 255))
    ld.ellipse((CENTER - 14, 161, CENTER + 3, 178), fill=(32, 56, 83, 255))
    ld.ellipse((CENTER - 8, 165, CENTER - 2, 171), fill=(126, 171, 218, 190))
    ld.ellipse((CENTER - 38, 164, CENTER - 26, 176), fill=(26, 33, 43, 255))

    # ---- glass prompter card --------------------------------------------------
    card_box = (338, 612, 1710, 1590)
    card_radius = 186
    card_mask = rounded_mask(card_box, card_radius)

    card_fill = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card_fill)
    card_draw.rounded_rectangle(card_box, radius=card_radius, fill=(5, 7, 11, 166))
    content.alpha_composite(card_fill)

    # card top wash
    wash = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    wd.rounded_rectangle(
        (card_box[0] + 3, card_box[1] + 3, card_box[2] - 3, card_box[3] - 3),
        radius=card_radius - 3,
        fill=(255, 255, 255, 0),
        outline=(255, 255, 255, 34),
        width=3,
    )
    wash = wash.filter(ImageFilter.GaussianBlur(0.4))
    content.alpha_composite(wash)

    # active line glow
    active_segments = [
        (534, 760, 982, 94),
        (792, 1010, 982, 94),
        (1042, 1190, 982, 94),
        (1222, 1508, 982, 94),
    ]
    content = soft_glow(
        content,
        [((x1, y, x2, y + h), h // 2) for (x1, x2, y, h) in active_segments],
        (247, 219, 167, 74),
        34,
    )

    draw = ImageDraw.Draw(content)

    # first dim line (segmented words)
    for x1, x2, y, h in [
        (534, 690, 842, 42),
        (720, 930, 842, 42),
        (960, 1060, 842, 42),
        (1090, 1290, 842, 42),
        (1320, 1478, 842, 42),
    ]:
        draw.rounded_rectangle((x1, y, x2, y + h), radius=h // 2, fill=(244, 244, 244, 62))

    # active line (warm)
    active_colors = [
        (255, 243, 219, 250),
        (246, 225, 188, 240),
        (250, 234, 203, 245),
        (239, 214, 174, 230),
    ]
    for (x1, x2, y, h), fill in zip(active_segments, active_colors):
        draw.rounded_rectangle((x1, y, x2, y + h), radius=h // 2, fill=fill)

    # third dim line
    for x1, x2, y, h in [
        (534, 812, 1198, 42),
        (844, 1048, 1198, 42),
        (1080, 1320, 1198, 42),
        (1352, 1450, 1198, 42),
    ]:
        draw.rounded_rectangle((x1, y, x2, y + h), radius=h // 2, fill=(244, 244, 244, 46))

    # progress track
    track = (534, 1432, 1512, 1444)
    draw.rounded_rectangle(track, radius=6, fill=(245, 245, 245, 34))
    # progress fill, warm gradient
    fill_end = int(track[0] + (track[2] - track[0]) * 0.64)
    gw = max(1, fill_end - track[0])
    gh = track[3] - track[1]
    grad = np.zeros((gh, gw, 4), dtype=np.uint8)
    for x in range(gw):
        t = x / max(1, gw - 1)
        col = lerp((144, 186, 231), (255, 231, 190), t)
        grad[:, x, :3] = col
        grad[:, x, 3] = 235
    grad_img = Image.fromarray(grad, "RGBA")
    fill_mask = Image.new("L", (gw, gh), 0)
    ImageDraw.Draw(fill_mask).rounded_rectangle((0, 0, gw - 1, gh - 1), radius=6, fill=255)
    content.paste(grad_img, (track[0], track[1]), fill_mask)
    # playhead
    cx, cy = fill_end, (track[1] + track[3]) // 2
    draw.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=(255, 250, 238, 255))
    draw.ellipse((cx - 28, cy - 28, cx + 28, cy + 28), outline=(255, 232, 188, 80), width=3)

    # warm specular on the card's top-left corner
    card_glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cg = ImageDraw.Draw(card_glow)
    cg.ellipse((390, 540, 1500, 930), fill=(163, 199, 239, 14))
    card_glow = card_glow.filter(ImageFilter.GaussianBlur(72))
    card_glow.putalpha(ImageChops.multiply(card_glow.getchannel("A"), card_mask))
    content = Image.alpha_composite(content, card_glow)

    content.putalpha(ImageChops.multiply(content.getchannel("A"), base_mask))
    canvas = Image.alpha_composite(canvas, content)

    # ---- final grain and resample --------------------------------------------
    grain_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grain_np = rng.normal(0, 1, (S, S, 1))
    grain_np = np.clip(128 + grain_np * 18, 0, 255).astype(np.uint8)
    grain_layer = Image.fromarray(
        np.concatenate(
            [
                np.repeat(grain_np, 3, axis=2),
                np.full((S, S, 1), 12, dtype=np.uint8),
            ],
            axis=2,
        ),
        "RGBA",
    )
    grain_layer.putalpha(ImageChops.multiply(grain_layer.getchannel("A"), base_mask))
    canvas = Image.alpha_composite(canvas, grain_layer)

    icon = canvas.resize((FINAL, FINAL), Image.LANCZOS)
    icon_path = os.path.join(RESOURCES, "NookIcon.png")
    icon.save(icon_path)

    # ---- icns -----------------------------------------------------------------
    os.makedirs(ICONSET, exist_ok=True)
    specs = [
        ("16x16", 16),
        ("16x16@2x", 32),
        ("32x32", 32),
        ("32x32@2x", 64),
        ("128x128", 128),
        ("128x128@2x", 256),
        ("256x256", 256),
        ("256x256@2x", 512),
        ("512x512", 512),
        ("512x512@2x", 1024),
    ]
    for name, size in specs:
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(ICONSET, f"icon_{name}.png"))

    subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", os.path.join(RESOURCES, "Nook.icns")], check=True)
    print(f"Wrote {icon_path}")
    print(f"Wrote {os.path.join(RESOURCES, 'Nook.icns')}")


if __name__ == "__main__":
    main()
