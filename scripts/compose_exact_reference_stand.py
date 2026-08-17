"""Compose A5 artwork using the supplied reference's exact visual treatments."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "deliverables" / "show-stand"
OUT.mkdir(parents=True, exist_ok=True)
REFERENCE = Path(r"C:\Users\KYAWZA~1\AppData\Local\Temp\codex-clipboard-882cf05f-b371-4f91-89b9-f4c821c5b580.png")
LAND = Path(r"C:\Users\Kyaw Zay Ya Hein\.codex\generated_images\01a010ca-17b4-7273-9a2f-484a19d7cc7c\exec-824005a4-9fff-4701-a360-c80369ec3ed3.png")
W, H = 2480, 1748


def resize(im, size):
    return im.resize(size, Image.Resampling.LANCZOS)


def cover(im, size):
    scale = max(size[0] / im.width, size[1] / im.height)
    im = resize(im, (round(im.width * scale), round(im.height * scale)))
    x, y = (im.width - size[0]) // 2, (im.height - size[1]) // 2
    return im.crop((x, y, x + size[0], y + size[1]))


def rounded_mask(size, radius):
    out = Image.new("L", size, 0)
    ImageDraw.Draw(out).rounded_rectangle((0, 0, *size), radius, fill=255)
    return out


def paste_phone(canvas, x, y, w, h, screen):
    shadow = Image.new("RGBA", (w + 52, h + 52), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((27, 27, w + 17, h + 17), radius=53, fill=(52, 31, 16, 100))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)), (x - 16, y - 6))
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x, y, x+w, y+h), radius=55, fill="#21170F", outline="#D2A05A", width=5)
    canvas.paste(screen, (x + 13, y + 13), rounded_mask((w - 26, h - 26), 44))
    d.rounded_rectangle((x + w/2 - 64, y + 22, x + w/2 + 64, y + 42), radius=12, fill="#20150E")


ref = Image.open(REFERENCE).convert("RGB")
canvas = Image.new("RGB", (W, H), ref.getpixel((50, 100)))
draw = ImageDraw.Draw(canvas)
draw.rectangle((0, 0, W - 1, H - 1), outline="#E1C5A0", width=7)
# These are the reference card's logo/header and feature-card treatments. They
# are resized together, not re-drawn, so the icon, texture, text weight, and
# small decorative elements remain exactly as in the approved visual direction.
header = ref.crop((40, 53, 640, 230))
features = ref.crop((40, 228, 640, 500))
canvas.paste(resize(header, (1120, 326)), (105, 75))
canvas.paste(resize(features, (1120, 510)), (105, 390))

# Reference-like lower Bagan horizon, kept behind phones and beneath the copied
# feature treatment, without the washed-out blur of the prior draft.
land = cover(Image.open(LAND).convert("RGB"), (W, 430))
canvas.paste(land, (0, 1080))
wash = Image.new("RGBA", (W, 430), (252, 236, 214, 0))
wd = ImageDraw.Draw(wash)
for y in range(210):
    wd.line((0, y, W, y), fill=(252, 236, 214, 220 - y), width=1)
band = canvas.crop((0, 1080, W, 1510)).convert("RGBA")
canvas.paste(Image.alpha_composite(band, wash).convert("RGB"), (0, 1080))

# Keep the approved real project screens and arrangement, but never paste their
# old poster background behind them.
slide3 = ROOT / "deliverables" / "Baganetic_10_Minute_Pitch_Revised" / "slide-3.png"
slide4 = ROOT / "deliverables" / "Baganetic_10_Minute_Pitch_Revised" / "slide-4.png"
map_screen = cover(Image.open(slide4).convert("RGB").crop((948, 42, 1306, 776)), (330, 830))
home_screen = cover(Image.open(slide3).convert("RGB").crop((862, 120, 1136, 711)), (480, 1160))
detail_screen = cover(Image.open(slide3).convert("RGB").crop((1187, 120, 1460, 711)), (330, 830))
canvas = canvas.convert("RGBA")
paste_phone(canvas, 1280, 375, 356, 856, map_screen)
paste_phone(canvas, 1570, 125, 506, 1186, home_screen)
paste_phone(canvas, 2072, 355, 356, 856, detail_screen)
canvas = canvas.convert("RGB")

# Exact reference bottom bar: original QR is replaced with the current working QR.
footer = ref.crop((40, 540, 1240, 610))
footer = resize(footer, (2280, 194))
canvas.paste(footer, (105, 1518))
qr = Image.open(ROOT / "tmp" / "baganetic-github-qr.png").convert("RGB")
qr = resize(qr, (154, 154))
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle((175, 1538, 349, 1702), radius=10, fill="#FFFFFF")
canvas.paste(qr, (185, 1543))

target = OUT / "Baganetic_Show_Stand_Reference_Exact_Treatment_A5_Landscape.png"
canvas.save(target, dpi=(300, 300), quality=95)
print(target)
