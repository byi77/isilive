from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 32
SCALE = 16
CORNER_RADIUS = 7
# Dark isiLive surface (SURFACE_ACTION_SECONDARY family) so the badge sits in
# the UI instead of shouting; only the glyph and rim carry the role color.
SURFACE_TOP = (36, 46, 66)
SURFACE_BOTTOM = (13, 17, 27)

# Glyph color and rim color, per role.
ROLE_COLORS = {
    "tank": ((125, 182, 255, 255), (90, 150, 235, 150)),
    "healer": ((112, 220, 142, 255), (80, 185, 110, 150)),
    "dps": ((255, 124, 108, 255), (220, 90, 80, 150)),
}


def scaled(points):
    return [(horizontal * SCALE, vertical * SCALE) for horizontal, vertical in points]


def bezier(start, control, end, steps=24):
    points = []
    for index in range(steps + 1):
        t = index / steps
        points.append(
            (
                (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * control[0] + t**2 * end[0],
                (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * control[1] + t**2 * end[1],
            )
        )
    return points


def glyph_tank(draw):
    outline = [(8.5, 7.5), (16, 5.5), (23.5, 7.5), (23.5, 14)]
    outline += bezier((23.5, 14), (23, 22), (16, 26.5))[1:]
    outline += bezier((16, 26.5), (9, 22), (8.5, 14))[1:]
    draw.polygon(scaled(outline), fill=255)


def glyph_healer(draw):
    draw.rounded_rectangle(scaled([(12.6, 6), (19.4, 26)]), radius=1.6 * SCALE, fill=255)
    draw.rounded_rectangle(scaled([(6, 12.6), (26, 19.4)]), radius=1.6 * SCALE, fill=255)


def glyph_dps(draw):
    # Bold diagonal sword, tip top-right, pommel bottom-left.
    blade = [(26, 6), (24.7, 10.3), (13.9, 21.1), (10.9, 18.1), (21.7, 7.3)]
    draw.polygon(scaled(blade), fill=255)
    draw.line(scaled([(7.2, 16.2), (15.8, 24.8)]), fill=255, width=int(3.3 * SCALE))
    draw.line(scaled([(11.6, 20.4), (8.0, 24.0)]), fill=255, width=int(3.1 * SCALE))
    radius = 2.3
    draw.ellipse(scaled([(6.9 - radius, 25.1 - radius), (6.9 + radius, 25.1 + radius)]), fill=255)


GLYPHS = {
    "tank": glyph_tank,
    "healer": glyph_healer,
    "dps": glyph_dps,
}


def vertical_gradient(size, top, bottom):
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    for vertical in range(size):
        mix = vertical / (size - 1)
        color = tuple(int(top[channel] + (bottom[channel] - top[channel]) * mix) for channel in range(3))
        for horizontal in range(size):
            pixels[horizontal, vertical] = color + (255,)
    return image


def make_badge(role):
    glyph_color, rim = ROLE_COLORS[role]
    size = SIZE * SCALE
    shape = Image.new("L", (size, size))
    ImageDraw.Draw(shape).rounded_rectangle((0, 0, size - 1, size - 1), radius=CORNER_RADIUS * SCALE, fill=255)

    badge = vertical_gradient(size, SURFACE_TOP, SURFACE_BOTTOM)

    # Glass highlight across the upper half, clipped to the badge.
    shine = Image.new("L", (size, size))
    ImageDraw.Draw(shine).ellipse((-0.3 * size, -0.75 * size, 1.3 * size, 0.42 * size), fill=22)
    badge.alpha_composite(Image.merge("RGBA", (*[Image.new("L", (size, size), 255)] * 3, shine)))

    glyph = Image.new("L", (size, size))
    GLYPHS[role](ImageDraw.Draw(glyph))
    shadow = glyph.filter(ImageFilter.GaussianBlur(0.9 * SCALE)).point(lambda alpha: alpha * 0.55)
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_layer.putalpha(shadow)
    badge.alpha_composite(shadow_layer, (0, int(0.7 * SCALE)))
    glyph_layer = Image.new("RGBA", (size, size), glyph_color)
    glyph_layer.putalpha(glyph)
    badge.alpha_composite(glyph_layer)

    badge.putalpha(shape)

    border = Image.new("RGBA", (size, size))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=CORNER_RADIUS * SCALE, outline=(0, 0, 0, 170), width=SCALE
    )
    border_draw.rounded_rectangle(
        (SCALE, SCALE, size - 1 - SCALE, size - 1 - SCALE),
        radius=(CORNER_RADIUS - 1) * SCALE,
        outline=rim,
        width=SCALE,
    )
    badge.alpha_composite(border)
    return badge.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main():
    media = Path(__file__).resolve().parent.parent / "media"
    for role in GLYPHS:
        make_badge(role).save(media / f"role_{role}.tga", compression=None)


if __name__ == "__main__":
    main()
