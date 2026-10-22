import math
from pathlib import Path

from PIL import Image, ImageDraw

WIDTH = 32
HEIGHT = 24
SCALE = 16
CORNER_RADIUS = 3
BORDER_COLOR = (0, 0, 0, 150)


def canvas():
    image = Image.new("RGBA", (WIDTH * SCALE, HEIGHT * SCALE))
    return image, ImageDraw.Draw(image)


def box(left, top, right, bottom):
    return (left * SCALE, top * SCALE, right * SCALE - 1, bottom * SCALE - 1)


def horizontal_bands(colors, weights=None):
    weights = weights or [1] * len(colors)
    image, draw = canvas()
    top = 0
    for color, weight in zip(colors, weights):
        bottom = top + HEIGHT * weight / sum(weights)
        draw.rectangle(box(0, top, WIDTH, bottom), fill=color)
        top = bottom
    return image, draw


def vertical_bands(colors, weights=None):
    weights = weights or [1] * len(colors)
    image, draw = canvas()
    left = 0
    for color, weight in zip(colors, weights):
        right = left + WIDTH * weight / sum(weights)
        draw.rectangle(box(left, 0, right, HEIGHT), fill=color)
        left = right
    return image, draw


def circle(draw, center_x, center_y, radius, color):
    draw.ellipse(
        (
            (center_x - radius) * SCALE,
            (center_y - radius) * SCALE,
            (center_x + radius) * SCALE,
            (center_y + radius) * SCALE,
        ),
        fill=color,
    )


def star(draw, center_x, center_y, radius, color, rotation=-math.pi / 2):
    points = []
    for index in range(10):
        reach = radius if index % 2 == 0 else radius * 0.382
        angle = rotation + index * math.pi / 5
        points.append(((center_x + reach * math.cos(angle)) * SCALE, (center_y + reach * math.sin(angle)) * SCALE))
    draw.polygon(points, fill=color)


def flag_de():
    return horizontal_bands([(21, 21, 21), (221, 0, 0), (255, 206, 0)])[0]


def flag_fr():
    return vertical_bands([(0, 85, 164), (255, 255, 255), (239, 65, 53)])[0]


def flag_it():
    return vertical_bands([(0, 146, 70), (255, 255, 255), (206, 43, 55)])[0]


def flag_ru():
    return horizontal_bands([(255, 255, 255), (0, 57, 166), (213, 43, 30)])[0]


def flag_es():
    image, draw = horizontal_bands([(170, 21, 27), (241, 191, 0), (170, 21, 27)], [1, 2, 1])
    # Simplified coat of arms: crowned shield between the two pillars.
    draw.rectangle(box(6.2, 9.5, 7.2, 15.5), fill=(200, 200, 200))
    draw.rectangle(box(12.8, 9.5, 13.8, 15.5), fill=(200, 200, 200))
    draw.rounded_rectangle(box(8, 9.5, 12, 15.5), radius=1.5 * SCALE, fill=(170, 21, 27))
    draw.rounded_rectangle(box(8.6, 10, 10, 12.5), radius=0.4 * SCALE, fill=(241, 191, 0))
    draw.rounded_rectangle(box(10, 10, 11.4, 12.5), radius=0.4 * SCALE, fill=(240, 240, 240))
    draw.rectangle(box(8.5, 8, 11.5, 9.2), fill=(205, 150, 30))
    return image


def flag_pt():
    image, draw = vertical_bands([(0, 102, 0), (255, 0, 0)], [2, 3])
    center_x = WIDTH * 2 / 5
    center_y = HEIGHT / 2
    # Armillary sphere as a yellow ring with the red/white shield on top.
    draw.ellipse(
        ((center_x - 5.2) * SCALE, (center_y - 5.2) * SCALE, (center_x + 5.2) * SCALE, (center_y + 5.2) * SCALE),
        outline=(255, 220, 0),
        width=int(1.3 * SCALE),
    )
    draw.rounded_rectangle(box(center_x - 2.6, center_y - 3, center_x + 2.6, center_y + 3), radius=1.6 * SCALE, fill=(255, 0, 0))
    draw.rounded_rectangle(box(center_x - 1.6, center_y - 2, center_x + 1.6, center_y + 2), radius=1 * SCALE, fill=(255, 255, 255))
    draw.rectangle(box(center_x - 0.5, center_y - 1.6, center_x + 0.5, center_y + 1.6), fill=(0, 51, 153))
    return image


def flag_tr():
    image, draw = canvas()
    red = (227, 10, 23)
    draw.rectangle(box(0, 0, WIDTH, HEIGHT), fill=red)
    unit = HEIGHT
    center_y = HEIGHT / 2
    circle(draw, 0.5 * unit, center_y, 0.25 * unit, (255, 255, 255))
    circle(draw, 0.5625 * unit, center_y, 0.2 * unit, red)
    star(draw, 0.86 * unit, center_y, 0.125 * unit, (255, 255, 255), rotation=math.pi)
    return image


def flag_en():
    image, draw = canvas()
    blue, red, white = (1, 33, 105), (200, 16, 46), (255, 255, 255)
    draw.rectangle(box(0, 0, WIDTH, HEIGHT), fill=blue)
    corners = [((0, 0), (WIDTH, HEIGHT)), ((0, HEIGHT), (WIDTH, 0))]
    for (start_x, start_y), (end_x, end_y) in corners:
        draw.line([(start_x * SCALE, start_y * SCALE), (end_x * SCALE, end_y * SCALE)], fill=white, width=5 * SCALE)
    # Counterchanged red saltire: each arm is offset clockwise from the diagonal.
    middle_x, middle_y = WIDTH / 2, HEIGHT / 2
    length = math.hypot(WIDTH, HEIGHT) / 2
    offset = 1.0
    for corner_x, corner_y in [(0, 0), (WIDTH, 0), (WIDTH, HEIGHT), (0, HEIGHT)]:
        direction_x = (corner_x - middle_x) / length
        direction_y = (corner_y - middle_y) / length
        shift_x, shift_y = -direction_y * offset, direction_x * offset
        draw.line(
            [
                ((middle_x + shift_x) * SCALE, (middle_y + shift_y) * SCALE),
                ((corner_x + shift_x) * SCALE, (corner_y + shift_y) * SCALE),
            ],
            fill=red,
            width=int(1.6 * SCALE),
        )
    draw.rectangle(box(0, middle_y - 4, WIDTH, middle_y + 4), fill=white)
    draw.rectangle(box(middle_x - 4, 0, middle_x + 4, HEIGHT), fill=white)
    draw.rectangle(box(0, middle_y - 2.4, WIDTH, middle_y + 2.4), fill=red)
    draw.rectangle(box(middle_x - 2.4, 0, middle_x + 2.4, HEIGHT), fill=red)
    return image


def finish(image):
    size_x, size_y = image.size
    # Soft top light and bottom shade so the flag reads as a raised badge.
    shading = Image.new("RGBA", image.size)
    pixels = shading.load()
    for vertical in range(size_y):
        position = vertical / size_y
        if position < 0.5:
            color = (255, 255, 255, int(30 * (1 - position / 0.5)))
        else:
            color = (0, 0, 0, int(34 * (position - 0.5) / 0.5))
        for horizontal in range(size_x):
            pixels[horizontal, vertical] = color
    image.alpha_composite(shading)

    mask = Image.new("L", image.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size_x - 1, size_y - 1), radius=CORNER_RADIUS * SCALE, fill=255)
    image.putalpha(mask)

    border = Image.new("RGBA", image.size)
    ImageDraw.Draw(border).rounded_rectangle(
        (0, 0, size_x - 1, size_y - 1),
        radius=CORNER_RADIUS * SCALE,
        outline=BORDER_COLOR,
        width=SCALE,
    )
    image.alpha_composite(border)
    return image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)


FLAGS = {
    "de": flag_de,
    "en": flag_en,
    "es": flag_es,
    "fr": flag_fr,
    "it": flag_it,
    "pt": flag_pt,
    "ru": flag_ru,
    "tr": flag_tr,
}


def main():
    flags = Path(__file__).resolve().parent.parent / "media" / "flags"
    for name, build in FLAGS.items():
        finish(build()).save(flags / f"{name}.tga", compression=None)


if __name__ == "__main__":
    main()
