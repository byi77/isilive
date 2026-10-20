from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


def make_marker(points, color):
    scale = 8
    image = Image.new("RGBA", (32 * scale, 32 * scale))
    draw = ImageDraw.Draw(image)
    for path in points:
        draw.line(
            [(horizontal * scale, vertical * scale) for horizontal, vertical in path],
            fill=color,
            width=3 * scale,
            joint="curve",
        )
    return image.resize((32, 32), Image.Resampling.LANCZOS)


def make_bonus_plus():
    scale = 8
    size = 32 * scale
    mask = Image.new("L", (size, size))
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((13 * scale, 4 * scale, 19 * scale, 28 * scale), radius=scale, fill=255)
    draw.rounded_rectangle((4 * scale, 13 * scale, 28 * scale, 19 * scale), radius=scale, fill=255)
    glow = Image.new("RGBA", (size, size), (20, 235, 92, 0))
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(1.4 * scale)).point(lambda alpha: alpha * 0.55))
    surface = Image.new("RGBA", (size, size))
    pixels = surface.load()
    for vertical in range(size):
        for horizontal in range(size):
            shine = max(0, 1 - abs(horizontal + vertical - 24 * scale) / (4 * scale))
            light = 1 - vertical / size
            pixels[horizontal, vertical] = (
                int(25 + 65 * light + 125 * shine),
                int(155 + 75 * light + 25 * shine),
                int(65 + 55 * light + 105 * shine),
                255,
            )
    surface.putalpha(mask)
    glow.alpha_composite(surface)
    return glow.resize((32, 32), Image.Resampling.LANCZOS)


def main():
    media = Path(__file__).resolve().parent.parent / "media"
    make_marker(
        [[(16, 3), (29, 16), (16, 29), (3, 16), (16, 3)]],
        (85, 215, 132, 255),
    ).save(media / "diamond_bonus_green.tga", compression=None)
    make_bonus_plus().save(media / "plus_bonus_green.tga", compression=None)
    make_marker(
        [
            [(4, 16), (28, 16)],
            [(11, 9), (4, 16), (11, 23)],
            [(21, 9), (28, 16), (21, 23)],
        ],
        (98, 180, 255, 255),
    ).save(media / "link_sync_blue.tga", compression=None)


if __name__ == "__main__":
    main()
