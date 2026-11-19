"""Genera los iconos Android de la app a partir de icon_mascot.png (render de render_icon.py).

  python tools/mascot/make_icons.py

- ic_launcher.png (iconos clasicos, cuadrado redondeado) en cada densidad.
- Icono adaptativo (Android 8+): fondo degradado + ic_launcher_foreground + monocromo (Android 13).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
SRC = Image.open(Path(__file__).with_name('icon_mascot.png')).convert('RGBA')
mascot = SRC.crop(SRC.getbbox())

TOP, BOTTOM = (214, 240, 192), (139, 201, 112)
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def gradient(size: int) -> Image.Image:
    img = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,))
    return img


def place(canvas: Image.Image, fraction: float, dy: float = 0.0) -> Image.Image:
    size = canvas.width
    box = round(size * fraction)
    m = mascot.copy()
    m.thumbnail((box, box), Image.LANCZOS)
    x = (size - m.width) // 2
    y = (size - m.height) // 2 + round(size * dy)
    canvas.alpha_composite(m, (x, y))
    return canvas


def legacy(px: int) -> Image.Image:
    big = 1024
    bg = gradient(big)
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=round(big * 0.23), fill=255)
    icon = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    icon.paste(bg, (0, 0), mask)
    place(icon, 0.8, 0.01)
    return icon.resize((px, px), Image.LANCZOS)


def foreground(px: int) -> Image.Image:
    # Lienzo de 108dp; solo el circulo central de 66dp es seguro (algunas mascaras recortan).
    big = Image.new('RGBA', (1080, 1080), (0, 0, 0, 0))
    place(big, 0.62, 0.005)
    return big.resize((px, px), Image.LANCZOS)


def monochrome(px: int) -> Image.Image:
    fg = foreground(px)
    alpha = fg.getchannel('A')
    mono = Image.new('RGBA', fg.size, (255, 255, 255, 0))
    mono.putalpha(alpha)
    return mono


for name, k in DENSITIES.items():
    folder = RES / f'mipmap-{name}'
    folder.mkdir(parents=True, exist_ok=True)
    legacy(round(48 * k)).save(folder / 'ic_launcher.png')
    foreground(round(108 * k)).save(folder / 'ic_launcher_foreground.png')
    monochrome(round(108 * k)).save(folder / 'ic_launcher_monochrome.png')

(RES / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
(RES / 'mipmap-anydpi-v26' / 'ic_launcher.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@drawable/ic_launcher_background" />\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
    '</adaptive-icon>\n',
    encoding='utf-8',
)
hexc = lambda c: '#FF%02X%02X%02X' % c  # noqa: E731
(RES / 'drawable' / 'ic_launcher_background.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
    f'    <gradient android:angle="270" android:startColor="{hexc(TOP)}" android:endColor="{hexc(BOTTOM)}" />\n'
    '</shape>\n',
    encoding='utf-8',
)
legacy(512).save(Path(__file__).with_name('icon_preview.png'))
print('ok')
