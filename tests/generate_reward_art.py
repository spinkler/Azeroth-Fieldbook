"""Build smooth white alpha masks from the existing 14-unit reward silhouettes.

Run with the bundled Python (Pillow installed). These development tools are not
packaged. White RGB under transparent pixels prevents dark filtering fringes.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE, SUPERSAMPLE = 64, 8


def render(vertices, name):
    size = SIZE * SUPERSAMPLE
    mask = Image.new('L', (size, size), 0)
    # A half-unit transparent margin protects the tips during texture filtering.
    points = [((0.5 + x * 13 / 14) * size / 14,
               (0.5 + y * 13 / 14) * size / 14) for x, y in vertices]
    ImageDraw.Draw(mask).polygon(points, fill=255)
    mask = mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    image = Image.new('RGBA', (SIZE, SIZE), 'white')
    image.putalpha(mask)
    image.save(ROOT / 'Artwork' / name, compression=None)


if __name__ == '__main__':
    star = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        radius = 7 if i % 2 == 0 else 3
        star.append((7 + math.cos(angle) * radius, 7 + math.sin(angle) * radius))
    render(star, 'RewardStar.tga')
    render([(1, 3), (4, 6), (7, 1), (10, 6), (13, 3), (12, 13), (2, 13)], 'RewardCrown.tga')
