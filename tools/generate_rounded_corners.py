"""Generate the rounded-corner textures of the Modern UI design.

Both files are the top-left quarter of a white circle on a transparent
32x32 canvas; the Lua side mirrors them with SetTexCoord for the other three
corners and tints them with SetVertexColor:

* media/corner_disc.tga  - filled quarter disc (surface corners)
* media/corner_ring6.tga - quarter ring whose stroke is one UI unit wide when
                           the corner is drawn at a 6-unit radius (main
                           window hairline)
* media/corner_shadow.tga - quarter of a soft shadow ring around a 6-unit
                           corner: transparent inside the corner arc, full
                           alpha at the arc, fading linearly to zero 7 units
                           further out (matches the straight edge shadows)

Edges are anti-aliased by supersampling. Run from the repository root:
    python tools/generate_rounded_corners.py
"""

from pathlib import Path

from PIL import Image

SIZE = 32
SUPERSAMPLE = 8
RING_RADIUS_UNITS = 6
SHADOW_SIZE_UNITS = 7


def shadow_falloff():
    """Radial alpha ramp of the corner shadow (no supersampling needed)."""
    image = Image.new("RGBA", (SIZE, SIZE))
    pixels = image.load()
    inner = SIZE * RING_RADIUS_UNITS / (RING_RADIUS_UNITS + SHADOW_SIZE_UNITS)
    for vertical in range(SIZE):
        for horizontal in range(SIZE):
            distance = ((SIZE - horizontal - 0.5) ** 2 + (SIZE - vertical - 0.5) ** 2) ** 0.5
            if distance < inner:
                alpha = 0
            else:
                alpha = max(0.0, 1 - (distance - inner) / (SIZE - inner))
            pixels[horizontal, vertical] = (255, 255, 255, round(255 * alpha))
    return image


def coverage(inside):
    image = Image.new("RGBA", (SIZE, SIZE))
    pixels = image.load()
    steps = SUPERSAMPLE * SUPERSAMPLE
    for vertical in range(SIZE):
        for horizontal in range(SIZE):
            hits = 0
            for sub_y in range(SUPERSAMPLE):
                for sub_x in range(SUPERSAMPLE):
                    # Distance from the quarter's centre at the bottom-right
                    # corner of the canvas (32, 32).
                    point_x = horizontal + (sub_x + 0.5) / SUPERSAMPLE
                    point_y = vertical + (sub_y + 0.5) / SUPERSAMPLE
                    distance = ((SIZE - point_x) ** 2 + (SIZE - point_y) ** 2) ** 0.5
                    if inside(distance):
                        hits += 1
            pixels[horizontal, vertical] = (255, 255, 255, round(255 * hits / steps))
    return image


def main():
    media = Path(__file__).resolve().parent.parent / "media"
    stroke = SIZE / RING_RADIUS_UNITS
    coverage(lambda distance: distance <= SIZE).save(media / "corner_disc.tga")
    coverage(lambda distance: SIZE - stroke <= distance <= SIZE).save(media / "corner_ring6.tga")
    shadow_falloff().save(media / "corner_shadow.tga")


if __name__ == "__main__":
    main()
