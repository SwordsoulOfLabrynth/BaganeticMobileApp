from pathlib import Path
import textwrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "deliverables" / "show-stand"
PNG_OUTPUT = OUTPUT_DIR / "Baganetic_Show_Stand_English_A4_Landscape_Modern.png"
PDF_OUTPUT = ROOT / "output" / "pdf" / "Baganetic_Show_Stand_English_A4_Landscape_Modern.pdf"
PHOTO = ROOT / "assets" / "images" / "pagodas" / "Mahezedi Pagoda" / "Mahazedi_Pagoda_(Bagan).jpg"
LOGO = ROOT / "assets" / "images" / "baganetic_launcher_icon.png"
PLAYFAIR = ROOT / "assets" / "fonts" / "PlayfairDisplay-Bold.ttf"
POPPINS = ROOT / "assets" / "fonts" / "Poppins-Regular.ttf"
POPPINS_BOLD = ROOT / "assets" / "fonts" / "Poppins-Bold.ttf"

W, H = 3508, 2480  # A4 landscape at 300 DPI

CREAM = "#F6F0E5"
INK = "#152838"
INK_SOFT = "#405565"
TERRACOTTA = "#B84F2D"
GOLD = "#D79A3B"
SAND = "#E7D5BA"
WHITE = "#FFFFFF"


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def cover(image: Image.Image, size: tuple[int, int], focus=(0.57, 0.35)) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, min(resized.width - target_w, round((resized.width - target_w) * focus[0])))
    top = max(0, min(resized.height - target_h, round((resized.height - target_h) * focus[1])))
    return resized.crop((left, top, left + target_w, top + target_h))


def multiline(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, font_obj, fill, spacing=12):
    draw.multiline_text(xy, text, font=font_obj, fill=fill, spacing=spacing)


def label(draw: ImageDraw.ImageDraw, x: int, y: int, title: str, copy: str, marker: str) -> None:
    draw.rounded_rectangle((x, y, x + 72, y + 72), radius=20, fill=TERRACOTTA)
    draw.text((x + 20, y + 9), marker, font=font(POPPINS_BOLD, 42), fill=WHITE)
    draw.text((x + 100, y + 3), title, font=font(POPPINS_BOLD, 34), fill=INK)
    draw.text((x + 100, y + 48), copy, font=font(POPPINS, 25), fill=INK_SOFT)


def make_qr() -> Image.Image:
    import qrcode

    code = qrcode.QRCode(version=4, box_size=12, border=2, error_correction=qrcode.constants.ERROR_CORRECT_M)
    code.add_data("https://github.com/SwordsoulOfLabyrinth/BaganeticMobileApp")
    code.make(fit=True)
    return code.make_image(fill_color=INK, back_color=WHITE).convert("RGB")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PDF_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    poster = Image.new("RGB", (W, H), CREAM)
    draw = ImageDraw.Draw(poster)

    # Right-side visual anchor: a real Bagan pagoda, toned for a restrained editorial feel.
    photo_box = (2225, 0, W, 1785)
    with Image.open(PHOTO) as photo:
        hero = cover(photo.convert("RGB"), (photo_box[2] - photo_box[0], photo_box[3] - photo_box[1]))
    hero = hero.filter(ImageFilter.GaussianBlur(0.35))
    poster.paste(hero, photo_box[:2])
    hero_shade = Image.new("RGBA", hero.size, (8, 27, 41, 82))
    poster.paste(Image.alpha_composite(hero.convert("RGBA"), hero_shade).convert("RGB"), photo_box[:2])

    # Visual structure and a restrained route motif.
    draw.rectangle((0, 0, 2225, H), fill=CREAM)
    draw.rectangle((0, 0, 22, H), fill=TERRACOTTA)
    draw.line((145, 247, 2025, 247), fill=SAND, width=4)
    draw.line((145, 1445, 2025, 1445), fill=SAND, width=3)

    # Brand lockup.
    with Image.open(LOGO) as raw_logo:
        logo = raw_logo.convert("RGBA").resize((144, 144), Image.Resampling.LANCZOS)
    poster.paste(logo, (145, 80), logo)
    draw.text((320, 93), "BAGANETIC", font=font(POPPINS_BOLD, 34), fill=TERRACOTTA)
    draw.text((320, 143), "SMART ROUTE & INFO GUIDE", font=font(POPPINS, 23), fill=INK_SOFT)

    # Exhibition-first headline: short, large and immediately legible.
    draw.text((145, 360), "Explore Bagan.", font=font(PLAYFAIR, 152), fill=INK)
    draw.text((145, 525), "Without losing your way.", font=font(PLAYFAIR, 96), fill=TERRACOTTA)
    intro = "An offline-first mobile companion that brings Bagan's pagodas, smart routes and travel guidance together."
    multiline(draw, (150, 705), "\n".join(textwrap.wrap(intro, width=43)), font(POPPINS, 37), INK_SOFT, spacing=18)

    # Three concise proof points - clear at stand distance.
    label(draw, 150, 1000, "OFFLINE MAPS", "Navigate even with limited connectivity.", "01")
    label(draw, 150, 1128, "SMART ROUTES", "Plan better journeys between pagodas.", "02")
    label(draw, 150, 1256, "LOCAL GUIDANCE", "Find stories, tips and travel context.", "03")

    # A simple mapped journey suggests the product without decorative clutter.
    route = [(1510, 1000), (1640, 945), (1760, 1010), (1870, 890), (2000, 960)]
    draw.line(route, fill=GOLD, width=10, joint="curve")
    for x, y in route:
        draw.ellipse((x - 18, y - 18, x + 18, y + 18), fill=CREAM, outline=TERRACOTTA, width=8)
    draw.text((1500, 1060), "PLAN YOUR DAY", font=font(POPPINS_BOLD, 28), fill=INK)
    draw.text((1500, 1105), "Pagodas - routes - travel help", font=font(POPPINS, 24), fill=INK_SOFT)

    # Photo overlay provides a single memorable statement.
    draw.rounded_rectangle((2325, 106, 3360, 295), radius=36, fill=(21, 40, 56))
    draw.text((2370, 148), "HERITAGE MEETS", font=font(POPPINS_BOLD, 25), fill="#F6D49A")
    draw.text((2370, 188), "intelligent travel", font=font(PLAYFAIR, 53), fill=WHITE)
    draw.rounded_rectangle((2325, 1420, 3180, 1544), radius=55, fill=GOLD)
    draw.text((2380, 1450), "BUILT FOR BAGAN", font=font(POPPINS_BOLD, 28), fill=INK)

    # Bottom footer: readable facts and strong scan action.
    draw.rectangle((0, 1785, W, H), fill=INK)
    draw.text((145, 1875), "A MOBILE GUIDE FOR CURIOUS EXPLORERS", font=font(POPPINS_BOLD, 29), fill="#F6D49A")
    draw.text((145, 1938), "Flutter  /  Firebase  /  SQLite  /  OpenStreetMap", font=font(POPPINS, 28), fill="#C6D3D8")
    draw.text((145, 2056), "Team Baganetic  |  MIIT CSE", font=font(POPPINS_BOLD, 33), fill=WHITE)
    draw.text((145, 2120), "Smart Route & Info Guide for Bagan Pagodas", font=font(POPPINS, 25), fill="#C6D3D8")

    qr = make_qr().resize((360, 360), Image.Resampling.NEAREST)
    poster.paste(qr, (2865, 1880))
    draw.text((2410, 1920), "SCAN TO", font=font(POPPINS_BOLD, 29), fill="#F6D49A")
    draw.text((2410, 1970), "EXPLORE THE PROJECT", font=font(POPPINS_BOLD, 35), fill=WHITE)
    draw.text((2410, 2040), "Source code and demo details", font=font(POPPINS, 24), fill="#C6D3D8")
    draw.text((2410, 2090), "github.com/SwordsoulOfLabyrinth", font=font(POPPINS, 21), fill="#C6D3D8")

    poster.save(PNG_OUTPUT, dpi=(300, 300), quality=95, subsampling=0)

    page_width, page_height = landscape(A4)
    pdf = canvas.Canvas(str(PDF_OUTPUT), pagesize=(page_width, page_height))
    pdf.setTitle("Baganetic - Modern A4 Landscape Exhibition Poster")
    pdf.drawImage(str(PNG_OUTPUT), 0, 0, width=page_width, height=page_height)
    pdf.showPage()
    pdf.save()
    print(PNG_OUTPUT)
    print(PDF_OUTPUT)


if __name__ == "__main__":
    main()
