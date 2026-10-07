"""Rebuild the approved Bestiary collage without regenerating source artwork.

Run with Pillow available. Edit Artwork/Sources/BestiaryCollage/layout.json
and retained PNGs first. Masks must follow any moved foreground silhouettes.
All development inputs are excluded from CurseForge through .pkgmeta.
"""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'Artwork/Sources/BestiaryCollage'


def sample(path, size, uv=(0, 1, 0, 1)):
    with Image.open(path) as source:
        image = source.convert('RGBA')
    left, right, top, bottom = uv
    box = (min(left, right)*image.width, top*image.height,
           max(left, right)*image.width, bottom*image.height)
    image = image.resize(size, Image.Resampling.BILINEAR, box=box)
    return ImageOps.mirror(image) if left > right else image


def smooth(t):
    return t*t*t*(t*(6*t-15)+10)


def build():
    layout = json.loads((SOURCES / 'layout.json').read_text(encoding='utf-8'))
    width, height = layout['canvas']
    canvas = Image.new('RGBA', (width, height))
    fades = layout['fades']

    def attenuate(rect, opacity):
        x, y, w, h = rect
        box = (round(x), round(y), round(x+w), round(y+h))
        box = (max(0, box[0]), max(0, box[1]),
               min(width, box[2]), min(height, box[3]))
        if box[2] <= box[0] or box[3] <= box[1]:
            return
        patch = canvas.crop(box)
        patch.putalpha(patch.getchannel('A').point(lambda a: round(a*(1-opacity))))
        canvas.paste(patch, box[:2])

    for layer in layout['layers']:
        x, y, w, h = layer['rect']
        size = (round(w), round(h))
        image = sample(SOURCES / layer['file'], size, layer.get('uv', (0, 1, 0, 1)))
        alpha = image.getchannel('A')
        if 'mask' in layer:
            mask = layer['mask']
            mx, my, mw, mh = mask['rect']
            # Clamped sampling matches native mask texture boundaries.
            mask_image = sample(SOURCES / mask['file'], (round(mw), round(mh))).getchannel('A')
            mask_alpha = Image.new('L', size, 255)
            pixels = mask_alpha.load()
            for py in range(size[1]):
                for px in range(size[0]):
                    sx = max(0, min(mask_image.width-1, round(x+px-mx)))
                    sy = max(0, min(mask_image.height-1, round(y+py-my)))
                    pixels[px, py] = mask_image.getpixel((sx, sy))
            alpha = ImageChops.multiply(alpha, mask_alpha)
        image.putalpha(alpha.point(lambda a: round(a*layer['opacity'])))
        canvas.alpha_composite(image, (round(x), round(y)))
        if layer['name'] == 'dragon':
            steps = fades['dragon_right']
            for i in range(steps):
                attenuate((x+w-1-i, y, 1, h), 1-i/(steps-1))

    by_name = {layer['name']: layer for layer in layout['layers']}
    # These overlays originally followed all foreground art, so attenuate the
    # complete collage rather than each source in isolation.
    for name, key in [('murloc', 'bottom_murloc'), ('prairie_dog', 'bottom_prairie_dog')]:
        x, y, w, h = by_name[name]['rect']
        steps = fades[key]
        for i in range(steps):
            attenuate((x, y+h-1-i, w, 1), 1-smooth(i/(steps-1)))
    steps = fades['gnoll_kobold_edges']
    for i in range(steps):
        opacity = 1-i/(steps-1)
        for name in ('gnoll', 'kobold'):
            x, y, w, h = by_name[name]['rect']
            edge = x+i if name == 'gnoll' else x+w-1-i
            attenuate((edge, y, 1, h), opacity)
            attenuate((x, y+h-1-i, w, 1), opacity)
    steps = fades['gnoll_diagonal_steps']
    size = fades['gnoll_diagonal_extent']/steps
    for row in range(steps):
        for column in range(steps-row):
            attenuate((6+column*size, height-6-(row+1)*size, size, size),
                      1-smooth((row+column+1)/steps))
    output = Image.new('RGBA', tuple(layout['texture']))
    output.paste(canvas, (0, 0))
    destination = ROOT / layout['output']
    output.save(destination, optimize=True)
    print(f'Built {destination.name}: {destination.stat().st_size:,} bytes')
    return output


if __name__ == '__main__':
    build()
