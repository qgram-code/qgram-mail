#!/usr/bin/env python3
"""Render the QGram Mail app icon (1024×1024 PNG) into the asset catalog.

No third-party dependencies: shapes are signed distance fields, antialiasing
comes from the distance itself, and the PNG is written with zlib.

    python3 scripts/generate_appicon.py
"""

from __future__ import annotations

import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(
    ROOT, "QGramMail", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png"
)

SIZE = 1024

# Nocturne (та же палитра, что в приложении).
BG_TOP = (0x1C, 0x1E, 0x30)
BG_BOTTOM = (0x0E, 0x0F, 0x18)
GLOW = (0x91, 0x84, 0xD9)
ENVELOPE_TOP = (0xB2, 0xA6, 0xF2)
ENVELOPE_BOTTOM = (0x7B, 0x6D, 0xCE)
FLAP = (0x12, 0x14, 0x1F)
BADGE_BG = (0x12, 0x14, 0x1F)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1, c2, t: float):
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def over(dst, src, alpha: float):
    return (
        lerp(dst[0], src[0], alpha),
        lerp(dst[1], src[1], alpha),
        lerp(dst[2], src[2], alpha),
    )


def rounded_rect_sd(px: float, py: float, cx: float, cy: float, hw: float, hh: float, r: float) -> float:
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


def segment_sd(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    denom = vx * vx + vy * vy
    t = 0.0 if denom == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / denom))
    return math.hypot(wx - vx * t, wy - vy * t)


def coverage(sd: float) -> float:
    """Покрытие пикселя по расстоянию до края — сглаживание без суперсэмплинга."""
    return max(0.0, min(1.0, 0.5 - sd))


def build() -> bytes:
    # Геометрия конверта.
    cx, cy = SIZE / 2, SIZE / 2 + 8
    hw, hh = 322.0, 226.0
    radius = 74.0

    left, right = cx - hw, cx + hw
    top, bottom = cy - hh, cy + hh

    # Клапан: от верхних углов к центру, с запасом внутрь корпуса.
    flap_inset = 54.0
    flap_left = (left + flap_inset, top + 26.0)
    flap_right = (right - flap_inset, top + 26.0)
    flap_apex = (cx, cy + 34.0)
    flap_half_width = 19.0

    glow_cx, glow_cy, glow_r = SIZE / 2, SIZE * 0.30, SIZE * 0.62

    # Значок Q, «приклеенный» к правому нижнему углу конверта.
    badge_cx, badge_cy, badge_r = right - 26.0, bottom - 18.0, 128.0
    q_r, q_stroke = 60.0, 15.0
    tail = q_r * 0.72
    q_tail_a = (badge_cx + tail * 0.60, badge_cy + tail * 0.60)
    q_tail_b = (badge_cx + tail * 1.28, badge_cy + tail * 1.28)

    rows = bytearray()
    for y in range(SIZE):
        py = y + 0.5
        # Фон: вертикальный градиент + мягкое свечение акцента сверху.
        base = mix(BG_TOP, BG_BOTTOM, py / SIZE)
        rows.append(0)  # filter type 0 (None)
        row = bytearray()
        for x in range(SIZE):
            px = x + 0.5

            glow_d = math.hypot(px - glow_cx, py - glow_cy) / glow_r
            glow_a = max(0.0, 1.0 - glow_d) ** 2 * 0.30
            color = over(base, GLOW, glow_a)

            body_sd = rounded_rect_sd(px, py, cx, cy, hw, hh, radius)

            # Тень под конвертом.
            shadow_sd = rounded_rect_sd(px, py - 26, cx, cy, hw + 6, hh + 6, radius)
            if shadow_sd < 70:
                shadow_a = max(0.0, min(1.0, (70 - shadow_sd) / 70)) ** 2 * 0.55
                color = over(color, (0x05, 0x06, 0x0C), shadow_a)

            body_a = coverage(body_sd)
            if body_a > 0:
                t = max(0.0, min(1.0, (py - top) / (bottom - top)))
                envelope = mix(ENVELOPE_TOP, ENVELOPE_BOTTOM, t)
                color = over(color, envelope, body_a)

                # Клапан рисуется только внутри корпуса.
                flap_sd = min(
                    segment_sd(px, py, flap_left[0], flap_left[1], flap_apex[0], flap_apex[1]),
                    segment_sd(px, py, flap_apex[0], flap_apex[1], flap_right[0], flap_right[1]),
                ) - flap_half_width
                flap_a = coverage(flap_sd) * body_a
                if flap_a > 0:
                    color = over(color, FLAP, flap_a)

            # Значок Q в правом нижнем углу — кольцо с «хвостом».
            badge_d = math.hypot(px - badge_cx, py - badge_cy)
            if badge_d < badge_r + 30:
                badge_a = coverage(badge_d - badge_r)
                if badge_a > 0:
                    color = over(color, BADGE_BG, badge_a)
                ring_a = coverage(abs(badge_d - q_r) - q_stroke)
                tail_a = coverage(
                    segment_sd(px, py, q_tail_a[0], q_tail_a[1], q_tail_b[0], q_tail_b[1]) - q_stroke
                )
                glyph_a = max(ring_a, tail_a)
                if glyph_a > 0:
                    color = over(color, GLOW, glyph_a)

            row += bytes(
                (
                    int(max(0, min(255, round(color[0])))),
                    int(max(0, min(255, round(color[1])))),
                    int(max(0, min(255, round(color[2])))),
                )
            )
        rows += row

    return bytes(rows)


def png(raw: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit RGB
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as handle:
        handle.write(png(build()))
    print(f"{os.path.relpath(OUT, ROOT)}: {SIZE}×{SIZE}, {os.path.getsize(OUT)} bytes")


if __name__ == "__main__":
    main()
