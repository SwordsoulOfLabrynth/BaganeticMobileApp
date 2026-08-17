"""Create bilingual, print-ready A5 landscape Baganetic show-stand inserts.

The composition follows the supplied school-show reference: a warm cream panel,
an app lockup on the left, three overlapping product screens on the right, and a
scan/technology/team strip along the bottom.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "deliverables" / "show-stand"
OUT.mkdir(parents=True, exist_ok=True)
W, H, PPI = 2480, 1748, 300  # finished A5 landscape, 210 x 148 mm
# Use the project's bundled Noto family for the Burmese artwork.  Its metrics
# render consistently in Pillow and on the exhibition-print export machine.
FONT_REGULAR = str(ROOT / "assets" / "fonts" / "NotoSansMyanmar-Regular.ttf")
FONT_BOLD = str(ROOT / "assets" / "fonts" / "NotoSansMyanmar-Bold.ttf")
FONT_SERIF = r"C:\Windows\Fonts\georgiab.ttf"
FONT_SANS = r"C:\Windows\Fonts\gadugib.ttf"
ICON_SOURCE = Path(r"C:\Users\Kyaw Zay Ya Hein\Downloads\Telegram Desktop\file_00000000370c821185222b13287e68c0.png")


def f(path, size):
    return ImageFont.truetype(path, size)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *size), radius, fill=255)
    return mask


def crop_new_icon():
    """Remove the supplied image's pure-black surround and retain the icon."""
    im = Image.open(ICON_SOURCE).convert("RGBA")
    rgb = im.convert("RGB")
    alpha = Image.new("L", im.size, 0)
    px = alpha.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = rgb.getpixel((x, y))
            # The supplied surround is RGB(0,0,0); dark-brown icon details remain.
            if r > 2 or g > 2 or b > 2:
                px[x, y] = 255
    box = alpha.getbbox()
    result = im.crop(box)
    result.putalpha(alpha.crop(box))
    return result


def fit_cover(im, size):
    ratio = max(size[0] / im.width, size[1] / im.height)
    im = im.resize((round(im.width * ratio), round(im.height * ratio)), Image.Resampling.LANCZOS)
    left, top = (im.width - size[0]) // 2, (im.height - size[1]) // 2
    return im.crop((left, top, left + size[0], top + size[1]))


def phone_screen(source, crop, size):
    return fit_cover(Image.open(source).convert("RGB").crop(crop), size)


def draw_feature_icon(draw, cx, cy, kind, color):
    draw.ellipse((cx-57, cy-57, cx+57, cy+57), fill=color)
    cream, brown = "#FFF8EA", "#663015"
    if kind == 0:  # pagoda
        draw.polygon([(cx,cy-31),(cx-27,cy+21),(cx+27,cy+21)], fill=cream)
        draw.rectangle((cx-31,cy+20,cx+31,cy+32), fill=cream)
        draw.rectangle((cx-20,cy+32,cx+20,cy+38), fill=cream)
    elif kind == 1:  # navigation pin
        draw.ellipse((cx-20,cy-34,cx+20,cy+6), outline=cream, width=7)
        draw.polygon([(cx-18,cy-2),(cx+18,cy-2),(cx,cy+38)], fill=cream)
        draw.ellipse((cx-7,cy-21,cx+7,cy-7), fill=color)
    elif kind == 2:  # trip calendar
        draw.rounded_rectangle((cx-31,cy-27,cx+31,cy+34), radius=7, outline=cream, width=7)
        draw.line((cx-30,cy-9,cx+30,cy-9), fill=cream, width=6)
        draw.line((cx-16,cy-37,cx-16,cy-19), fill=cream, width=7)
        draw.line((cx+16,cy-37,cx+16,cy-19), fill=cream, width=7)
    elif kind == 3:  # AI sparkle
        draw.ellipse((cx-28,cy-28,cx+28,cy+28), outline=cream, width=6)
        draw.line((cx,cy-42,cx,cy+42), fill=cream, width=5)
        draw.line((cx-42,cy,cx+42,cy), fill=cream, width=5)
        draw.ellipse((cx-6,cy-6,cx+6,cy+6), fill=cream)
    else:  # road report
        draw.line((cx-23,cy+37,cx+8,cy-35), fill=cream, width=10)
        draw.line((cx+17,cy+37,cx+33,cy-3), fill=cream, width=10)
        draw.line((cx-9,cy+3,cx+16,cy+3), fill=brown, width=5)


def paste_phone(canvas, xy, size, screen):
    x, y = xy
    w, h = size
    shadow = Image.new("RGBA", (w+50, h+50), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((25, 25, w+20, h+20), radius=55, fill=(43, 24, 13, 105))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)), (x-15, y-5))
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x, y, x+w, y+h), radius=53, fill="#211710", outline="#805431", width=5)
    inset = 14
    canvas.paste(screen, (x+inset, y+inset), rounded_mask((w-inset*2, h-inset*2), 43))


def create(language):
    canvas = Image.new("RGBA", (W, H), "#FFF7EA")
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, W, H), outline="#E4CCAB", width=8)

    bg = fit_cover(Image.open(ROOT / "assets" / "images" / "stitch" / "bagan_sunrise.jpg").convert("RGB"), (W, 480)).filter(ImageFilter.GaussianBlur(1.1)).convert("RGBA")
    bg.putalpha(50)
    canvas.alpha_composite(bg, (0, 1040))
    draw = ImageDraw.Draw(canvas)

    icon = crop_new_icon()
    icon.thumbnail((220, 220), Image.Resampling.LANCZOS)
    canvas.alpha_composite(icon, (130, 102))
    draw = ImageDraw.Draw(canvas)
    draw.text((385, 122), "Baganetic", font=f(FONT_SERIF, 102), fill="#472918")
    if language == "en":
        tag, intro = "Explore Bagan. Plan Your Journey.", "Your all-in-one travel companion for discovering Bagan.\nExplore pagodas, build a trip, navigate with maps,\nand keep travelling even when you are offline."
        feature_titles = ["Discover", "Navigate", "Plan Trips", "AI Assistant", "Road Reports"]
        feature_notes = ["Explore pagodas", "Maps & routes", "Build your day", "Ask about Bagan", "Share travel info"]
        scan_title, scan_note = "SCAN TO EXPLORE", "Project source & demo info"
        team = "Team Baganetic   •   MIIT | CSE"
        title_font, body_font, feature_font = f(FONT_SANS, 38), f(FONT_SANS, 30), f(FONT_SANS, 27)
    else:
        tag, intro = "ဗဂန်ကို ရှာဖွေပါ။ ခရီးစဉ်ကို စီစဉ်ပါ။", "ဗဂန်ဘုရားများကို ရှာဖွေ၊ ခရီးစဉ်တည်ဆောက်၊\nမြေပုံဖြင့် လမ်းညွှန်ပြီး offline မှာပါ\nအဆင်ပြေစွာ ခရီးသွားနိုင်တဲ့ app တစ်ခုပါ။"
        feature_titles = ["ဘုရားများ", "လမ်းညွှန်", "ခရီးစဉ်", "AI အကူအညီ", "လမ်းသတင်း"]
        feature_notes = ["အသေးစိတ်ကြည့်ပါ", "မြေပုံနှင့်လမ်းကြောင်း", "ခရီးစဉ်စီစဉ်ပါ", "ဗဂန်အကြောင်းမေးပါ", "သတင်းပေးပို့ပါ"]
        scan_title, scan_note = "PROJECT ကို SCAN လုပ်ကြည့်ပါ", "source နှင့် demo info"
        team = "Baganetic Team   •   MIIT | CSE"
        title_font, body_font, feature_font = f(FONT_REGULAR, 36), f(FONT_REGULAR, 28), f(FONT_REGULAR, 22)
    draw.text((390, 244), tag, font=title_font, fill="#B45B2C")
    draw.line((390, 312, 1130, 312), fill="#D5A36D", width=3)
    draw.multiline_text((150, 395), intro, font=body_font, fill="#4E3324", spacing=14)

    palette = ["#D9874C", "#718A5A", "#B87439", "#826D8D", "#D17939"]
    centers = [230, 445, 660, 875, 1090]
    for i, cx in enumerate(centers):
        draw_feature_icon(draw, cx, 753, i, palette[i])
        box = draw.textbbox((0, 0), feature_titles[i], font=feature_font)
        draw.text((cx-(box[2]-box[0])/2, 838), feature_titles[i], font=feature_font, fill="#44281A")
        note_font = f(FONT_SANS if language == "en" else FONT_REGULAR, 20)
        box = draw.textbbox((0, 0), feature_notes[i], font=note_font)
        draw.text((cx-(box[2]-box[0])/2, 877), feature_notes[i], font=note_font, fill="#765B49")

    slide3 = ROOT / "deliverables" / "Baganetic_10_Minute_Pitch_Revised" / "slide-3.png"
    slide4 = ROOT / "deliverables" / "Baganetic_10_Minute_Pitch_Revised" / "slide-4.png"
    left = phone_screen(slide4, (948, 42, 1306, 776), (340, 780))
    middle = phone_screen(slide3, (1187, 120, 1460, 711), (490, 1190))
    right = phone_screen(slide3, (862, 120, 1136, 711), (340, 780))
    paste_phone(canvas, (1300, 455), (368, 808), left)
    paste_phone(canvas, (1630, 135), (518, 1218), middle)
    paste_phone(canvas, (2105, 425), (368, 808), right)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((95, 1432, 2385, 1662), radius=32, fill="#FFF4E3", outline="#E2C193", width=3)
    qr_path = ROOT / "tmp" / "baganetic-github-qr.png"
    if qr_path.exists():
        qr = Image.open(qr_path).convert("RGB").resize((172, 172), Image.Resampling.NEAREST)
        canvas.paste(qr, (128, 1462))
    draw.text((328, 1482), scan_title, font=f(FONT_SANS if language == "en" else FONT_BOLD, 29), fill="#B45B2C")
    draw.text((328, 1531), scan_note, font=f(FONT_SANS if language == "en" else FONT_REGULAR, 24), fill="#5E402C")
    draw.text((328, 1582), "github.com/SwordsoulOfLabrynth/BaganeticMobileApp", font=f(FONT_SANS, 20), fill="#765B49")
    draw.line((960, 1464, 960, 1630), fill="#DEC39D", width=3)
    techs = [("Flutter", "#4CA6C7"), ("Firebase", "#E4A532"), ("SQLite", "#6B94B5"), ("Offline Maps", "#6A9A77"), ("AI Guide", "#826D8D")]
    x = 1010
    for name, color in techs:
        draw.ellipse((x, 1500, x+48, 1548), fill=color)
        draw.text((x+62, 1506), name, font=f(FONT_SANS, 23), fill="#4E3324")
        x += 220
    draw.text((1010, 1590), team, font=f(FONT_SANS, 26), fill="#7B5B45")

    output = OUT / ("Baganetic_Show_Stand_English_A5_Landscape.png" if language == "en" else "Baganetic_Show_Stand_Myanmar_A5_Landscape.png")
    canvas.convert("RGB").save(output, dpi=(PPI, PPI), quality=95)
    return output


if __name__ == "__main__":
    for lang in ("en", "my"):
        print(create(lang))
