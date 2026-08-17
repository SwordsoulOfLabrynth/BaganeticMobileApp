"""Manual A5 re-layout based on the supplied Baganetic stand reference."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "deliverables" / "show-stand"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2480, 1748
F_SERIF = r"C:\Windows\Fonts\georgiab.ttf"
F_SANS = r"C:\Windows\Fonts\gadugib.ttf"
ICON = Path(r"C:\Users\Kyaw Zay Ya Hein\Downloads\Telegram Desktop\file_00000000370c821185222b13287e68c0.png")


def font(path, size):
    return ImageFont.truetype(path, size)


def crop_icon():
    im = Image.open(ICON).convert("RGBA")
    alpha = Image.new("L", im.size, 0)
    px = alpha.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = im.getpixel((x, y))
            if r > 2 or g > 2 or b > 2:
                px[x, y] = 255
    box = alpha.getbbox()
    im = im.crop(box)
    im.putalpha(alpha.crop(box))
    return im


def fit(im, size):
    ratio = max(size[0] / im.width, size[1] / im.height)
    im = im.resize((round(im.width * ratio), round(im.height * ratio)), Image.Resampling.LANCZOS)
    x, y = (im.width - size[0]) // 2, (im.height - size[1]) // 2
    return im.crop((x, y, x + size[0], y + size[1]))


def mask(size, radius):
    out = Image.new("L", size, 0)
    ImageDraw.Draw(out).rounded_rectangle((0, 0, *size), radius, fill=255)
    return out


def phone(canvas, x, y, w, h, screen):
    sh = Image.new("RGBA", (w + 50, h + 50), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((28, 28, w + 16, h + 16), radius=54, fill=(41, 23, 15, 105))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)), (x - 16, y - 6))
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x, y, x + w, y + h), radius=55, fill="#22160F", outline="#D5AA63", width=5)
    canvas.paste(screen, (x + 13, y + 13), mask((w - 26, h - 26), 44))
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x + w / 2 - 65, y + 22, x + w / 2 + 65, y + 42), radius=12, fill="#20150E")


def glyph(draw, cx, cy, n, colour):
    cream = "#FFF8E9"
    draw.ellipse((cx - 48, cy - 48, cx + 48, cy + 48), fill=colour)
    if n == 0:
        draw.polygon([(cx, cy - 29), (cx - 25, cy + 21), (cx + 25, cy + 21)], fill=cream)
        draw.rectangle((cx - 29, cy + 18, cx + 29, cy + 30), fill=cream)
    elif n == 1:
        draw.ellipse((cx - 18, cy - 31, cx + 18, cy + 5), outline=cream, width=6)
        draw.polygon([(cx - 16, cy - 2), (cx + 16, cy - 2), (cx, cy + 34)], fill=cream)
    elif n == 2:
        draw.rounded_rectangle((cx - 27, cy - 25, cx + 27, cy + 28), radius=6, outline=cream, width=6)
        draw.line((cx - 26, cy - 7, cx + 26, cy - 7), fill=cream, width=5)
    elif n == 3:
        draw.rounded_rectangle((cx - 27, cy - 23, cx + 27, cy + 21), radius=12, outline=cream, width=6)
        draw.ellipse((cx - 13, cy - 7, cx - 5, cy + 1), fill=cream)
        draw.ellipse((cx + 5, cy - 7, cx + 13, cy + 1), fill=cream)
        draw.line((cx - 10, cy + 11, cx + 10, cy + 11), fill=cream, width=4)
    else:
        draw.rounded_rectangle((cx - 31, cy - 12, cx + 31, cy + 18), radius=8, outline=cream, width=6)
        draw.ellipse((cx - 20, cy + 7, cx - 8, cy + 19), outline=cream, width=4)
        draw.ellipse((cx + 8, cy + 7, cx + 20, cy + 19), outline=cream, width=4)


canvas = Image.new("RGBA", (W, H), "#FFF3E2")
d = ImageDraw.Draw(canvas)
d.rectangle((0, 0, W - 1, H - 1), outline="#E1C7A3", width=7)

# Header and exact information hierarchy of the reference.
icon = crop_icon()
icon.thumbnail((230, 230), Image.Resampling.LANCZOS)
canvas.alpha_composite(icon, (130, 100))
d = ImageDraw.Draw(canvas)
d.text((395, 112), "Baganetic", font=font(F_SERIF, 110), fill="#4A2716")
d.text((399, 245), "Explore Bagan. Plan Your Journey.", font=font(F_SANS, 35), fill="#AF552A")
d.line((398, 320, 900, 320), fill="#BA7850", width=3)
# small temple divider, like the centre divider in the reference
d.polygon([(940, 305), (958, 270), (976, 305)], fill="#BE7C4E")
d.rectangle((931, 305, 985, 313), fill="#BE7C4E")

description = "Your all-in-one travel companion for exploring\nBagan. Discover pagodas, plan trips, navigate\noffline, get road updates, and travel smarter\nwith AI assistance."
d.multiline_text((395, 380), description, font=font(F_SANS, 27), fill="#33241C", spacing=9)

# The reference's faint travel cues add warmth without competing with the copy.
for bx, by in ((190, 585), (1175, 600)):
    d.ellipse((bx-20, by-28, bx+20, by+27), fill="#F1C486")
    d.polygon([(bx-10, by+22), (bx+10, by+22), (bx, by+47)], fill="#F1C486")
    d.line((bx, by+47, bx, by+58), fill="#D19A63", width=2)
d.line((270, 625, 355, 625), fill="#E6C792", width=2)
d.line((1080, 642, 1160, 642), fill="#E6C792", width=2)

# Five tightly aligned feature cards, with the same compact left-panel rhythm.
features = [
    ("Discover", "Explore 300+\npagodas with\ndetails.", "#DAA168"),
    ("Navigate", "Offline maps\n& smart route\nnavigation.", "#71905B"),
    ("Plan Trips", "Create your trip,\nsave favorites\n& itineraries.", "#B46A35"),
    ("AI Assistant", "Ask anything\nabout Bagan.\nGet instant help.", "#88718B"),
    ("Road Reports", "Real-time road\nconditions &\ntraveler reports.", "#CD783A"),
]
centres = [205, 420, 635, 850, 1065]
for i, ((title, note, colour), cx) in enumerate(zip(features, centres)):
    glyph(d, cx, 735, i, colour)
    tfont = font(F_SANS, 25)
    box = d.textbbox((0, 0), title, font=tfont)
    d.text((cx - (box[2] - box[0]) / 2, 805), title, font=tfont, fill="#352319")
    d.multiline_text((cx - 76, 845), note, font=font(F_SANS, 19), fill="#4E3627", spacing=4, align="center")

# A deliberately crisp, golden Bagan horizon—closer to the reference than the
# earlier washed-out photographic band. This generated art carries no text/UI.
land_path = Path(r"C:\Users\Kyaw Zay Ya Hein\.codex\generated_images\01a010ca-17b4-7273-9a2f-484a19d7cc7c\exec-824005a4-9fff-4701-a360-c80369ec3ed3.png")
land = fit(Image.open(land_path).convert("RGB"), (W, 440)).convert("RGBA")
canvas.alpha_composite(land, (0, 1040))

# Use three actual project captures in the same size and depth order as the reference.
slide3 = ROOT / "deliverables" / "Baganetic_10_Minute_Pitch_Revised" / "slide-3.png"
slide4 = ROOT / "deliverables" / "Baganetic_10_Minute_Pitch_Revised" / "slide-4.png"
map_screen = fit(Image.open(slide4).convert("RGB").crop((948, 42, 1306, 776)), (330, 830))
home_screen = fit(Image.open(slide3).convert("RGB").crop((862, 120, 1136, 711)), (480, 1160))
detail_screen = fit(Image.open(slide3).convert("RGB").crop((1187, 120, 1460, 711)), (330, 830))
phone(canvas, 1280, 375, 356, 856, map_screen)
phone(canvas, 1570, 125, 506, 1186, home_screen)
phone(canvas, 2072, 355, 356, 856, detail_screen)

# Bottom band mirrors the reference: high-contrast QR, branded stack marks, team.
d = ImageDraw.Draw(canvas)
d.rectangle((0, 1428, W, H), fill="#FFF1DE")
d.line((0, 1428, W, 1428), fill="#D9B281", width=3)
qr = Image.open(ROOT / "tmp" / "baganetic-github-qr.png").convert("RGB").resize((175, 175), Image.Resampling.NEAREST)
d.rounded_rectangle((90, 1462, 305, 1678), radius=12, fill="#FFFFFF", outline="#E2C18B", width=3)
canvas.paste(qr, (110, 1483))
d = ImageDraw.Draw(canvas)
d.text((340, 1510), "SCAN TO EXPLORE", font=font(F_SANS, 32), fill="#B45A2C")
d.text((340, 1558), "Try the app  •  View demo  •  GitHub", font=font(F_SANS, 21), fill="#5D3D2A")
d.line((770, 1480, 770, 1648), fill="#D5AF7C", width=2)

def stack_mark(x, label, kind):
    # Compact logo-like marks instead of generic colour dots.
    if kind == 0:  # Flutter angular blue ribbon
        d.polygon([(x, 1514), (x+28, 1492), (x+46, 1510), (x+20, 1536)], fill="#49A6D2")
        d.polygon([(x+20, 1536), (x+46, 1510), (x+56, 1521), (x+28, 1547)], fill="#1F80B4")
    elif kind == 1:  # Firebase flame
        d.polygon([(x+28, 1492), (x+50, 1522), (x+31, 1548), (x+12, 1522)], fill="#F7B733")
        d.polygon([(x+28, 1492), (x+31, 1548), (x+18, 1527)], fill="#F28B24")
    elif kind == 2:  # SQLite blue database
        d.ellipse((x+7, 1496, x+49, 1511), fill="#4E9CC5")
        d.rectangle((x+7, 1503, x+49, 1538), fill="#4E9CC5")
        d.ellipse((x+7, 1530, x+49, 1545), fill="#2F7FAD")
    elif kind == 3:  # Offline maps folded map
        d.rounded_rectangle((x+7, 1496, x+50, 1545), radius=6, fill="#DCE7CF", outline="#67905C", width=3)
        d.line((x+22, 1498, x+22, 1543), fill="#67905C", width=2)
        d.line((x+36, 1498, x+36, 1543), fill="#67905C", width=2)
    else:  # AI chip
        d.rounded_rectangle((x+8, 1498, x+49, 1540), radius=7, fill="#DDE8D3", outline="#5D8555", width=3)
        d.text((x+17, 1506), "AI", font=font(F_SANS, 17), fill="#416D3E")
    d.text((x+68, 1509), label, font=font(F_SANS, 21), fill="#3C2A20")

stack_mark(815, "Flutter", 0)
stack_mark(1038, "Firebase", 1)
stack_mark(1275, "SQLite", 2)
stack_mark(1495, "Offline Maps", 3)
stack_mark(1765, "AI Integration", 4)
d.ellipse((2070, 1485, 2140, 1555), fill="#F0D9AE")
d.ellipse((2094, 1498, 2118, 1522), outline="#59341E", width=4)
d.arc((2084, 1518, 2128, 1550), 190, 350, fill="#59341E", width=4)
d.text((2160, 1494), "Team Baganetic", font=font(F_SANS, 21), fill="#3C2A20")
d.text((2160, 1530), "MIIT  •  CSE", font=font(F_SANS, 19), fill="#5D3D2A")

target = OUT / "Baganetic_Show_Stand_Reference_Refined_A5_Landscape.png"
canvas.convert("RGB").save(target, dpi=(300, 300), quality=95)
print(target)
