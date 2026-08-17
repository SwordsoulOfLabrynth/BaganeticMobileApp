from pathlib import Path
import textwrap

from PIL import Image, ImageDraw, ImageEnhance, ImageFont
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "deliverables" / "show-stand"
PNG = OUT_DIR / "Baganetic_Show_Stand_English_A4_Landscape_Exhibition_Board.png"
PDF = ROOT / "output" / "pdf" / "Baganetic_Show_Stand_English_A4_Landscape_Exhibition_Board.pdf"
PHOTO = ROOT / "assets" / "images" / "pagodas" / "Mahezedi Pagoda" / "Mahazedi_Pagoda_(Bagan).jpg"
LOGO = ROOT / "assets" / "images" / "baganetic_launcher_icon.png"
PLAYFAIR = ROOT / "assets" / "fonts" / "PlayfairDisplay-Bold.ttf"
POPPINS = ROOT / "assets" / "fonts" / "Poppins-Regular.ttf"
POPPINS_BOLD = ROOT / "assets" / "fonts" / "Poppins-Bold.ttf"

W, H = 3508, 2480
NAVY = "#092A3A"
INK = "#173346"
CREAM = "#FAF7F1"
ORANGE = "#D75A36"
GOLD = "#E6AA3C"
BLUE = "#63B8D6"
MINT = "#93C7AB"
LINE = "#D7E1E1"
MUTED = "#617280"
WHITE = "#FFFFFF"


def f(path: Path, size: int):
    return ImageFont.truetype(str(path), size)


def cover(image: Image.Image, target: tuple[int, int]) -> Image.Image:
    tw, th = target
    scale = max(tw / image.width, th / image.height)
    nw, nh = round(image.width * scale), round(image.height * scale)
    resized = image.resize((nw, nh), Image.Resampling.LANCZOS)
    # Favor the pagoda in the upper-right portion of the original image.
    left = max(0, min(nw - tw, int((nw - tw) * 0.63)))
    top = max(0, min(nh - th, int((nh - th) * 0.08)))
    return resized.crop((left, top, left + tw, top + th))


def wrapped(draw, x, y, text, width, font_obj, fill, gap=12):
    lines = textwrap.wrap(text, width=width)
    draw.multiline_text((x, y), "\n".join(lines), font=font_obj, fill=fill, spacing=gap)


def section_heading(draw, x, y, number, heading):
    draw.rounded_rectangle((x, y, x + 66, y + 48), radius=12, fill=ORANGE)
    draw.text((x + 15, y + 7), number, font=f(POPPINS_BOLD, 25), fill=WHITE)
    draw.text((x + 90, y + 4), heading, font=f(POPPINS_BOLD, 32), fill=INK)


def feature(draw, x, y, color, title, detail):
    draw.ellipse((x, y, x + 36, y + 36), fill=color)
    draw.text((x + 58, y - 7), title, font=f(POPPINS_BOLD, 29), fill=INK)
    draw.text((x + 58, y + 33), detail, font=f(POPPINS, 22), fill=MUTED)


def qr_image():
    import qrcode

    code = qrcode.QRCode(version=4, box_size=12, border=2, error_correction=qrcode.constants.ERROR_CORRECT_M)
    code.add_data("https://github.com/SwordsoulOfLabyrinth/BaganeticMobileApp")
    code.make(fit=True)
    return code.make_image(fill_color=NAVY, back_color=WHITE).convert("RGB")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PDF.parent.mkdir(parents=True, exist_ok=True)
    poster = Image.new("RGB", (W, H), CREAM)
    draw = ImageDraw.Draw(poster)

    # Header: a compact academic identity rather than a marketing hero.
    draw.rectangle((0, 0, W, 660), fill=NAVY)
    with Image.open(PHOTO) as raw:
        image = cover(raw.convert("RGB"), (860, 660))
    image = ImageEnhance.Color(image).enhance(0.75)
    poster.paste(image, (0, 0))
    shade = Image.new("RGBA", (860, 660), (9, 42, 58, 90))
    poster.paste(Image.alpha_composite(image.convert("RGBA"), shade).convert("RGB"), (0, 0))
    draw.rectangle((860, 0, W, 660), fill=NAVY)
    draw.rectangle((860, 0, 884, 660), fill=GOLD)

    with Image.open(LOGO) as icon:
        logo = icon.convert("RGBA").resize((100, 100), Image.Resampling.LANCZOS)
    poster.paste(logo, (960, 75), logo)
    draw.text((1090, 84), "BAGANETIC", font=f(POPPINS_BOLD, 38), fill="#F7CB71")
    draw.text((1090, 138), "SMART ROUTE & INFO GUIDE FOR BAGAN PAGODAS", font=f(POPPINS, 25), fill="#C9D8DE")
    draw.text((955, 240), "A smart travel companion", font=f(PLAYFAIR, 78), fill=WHITE)
    draw.text((955, 334), "for heritage exploration.", font=f(PLAYFAIR, 78), fill=WHITE)
    draw.text((960, 468), "Offline maps, on-device routes, local information and guided discovery - made for Bagan.", font=f(POPPINS, 29), fill="#D5E0E4")

    # Body alignment grid.
    draw.line((90, 740, W - 90, 740), fill=LINE, width=3)
    for x in (90, 1145, 2220, 3418):
        draw.line((x, 780, x, 1990), fill=LINE, width=3)

    # Column 1: problem and purpose.
    section_heading(draw, 90, 805, "01", "THE CHALLENGE")
    draw.text((90, 895), "2,000+", font=f(PLAYFAIR, 112), fill=ORANGE)
    draw.text((90, 1020), "ancient pagodas across a vast landscape", font=f(POPPINS_BOLD, 31), fill=INK)
    wrapped(draw, 90, 1090, "Tourists can face long distances, limited signage and unreliable connectivity while trying to explore Bagan.", 39, f(POPPINS, 27), MUTED, 13)
    draw.line((90, 1295, 1030, 1295), fill=LINE, width=3)
    draw.text((90, 1360), "OUR RESPONSE", font=f(POPPINS_BOLD, 25), fill=ORANGE)
    wrapped(draw, 90, 1415, "A mobile-first guide that helps visitors discover, plan and navigate with confidence - even when connectivity is limited.", 42, f(POPPINS_BOLD, 35), INK, 16)

    # Column 2: visual architecture, intentionally diagrammatic instead of a phone collage.
    section_heading(draw, 1145, 805, "02", "HOW IT WORKS")
    nodes = [
        (1265, 1010, "PAGODA\nDATA", BLUE),
        (1640, 1175, "ROUTE\nENGINE", GOLD),
        (1970, 990, "TRAVEL\nGUIDE", MINT),
        (1640, 1545, "BAGANETIC\nAPP", ORANGE),
    ]
    connections = [((1265, 1010), (1640, 1175)), ((1640, 1175), (1970, 990)), ((1265, 1010), (1640, 1545)), ((1640, 1175), (1640, 1545)), ((1970, 990), (1640, 1545))]
    for (x1, y1), (x2, y2) in connections:
        draw.line((x1, y1, x2, y2), fill="#A8C8D2", width=10)
        draw.line((x1, y1, x2, y2), fill=WHITE, width=4)
    for x, y, text, color in nodes:
        draw.ellipse((x - 112, y - 112, x + 112, y + 112), fill=WHITE, outline=color, width=12)
        draw.multiline_text((x, y - 38), text, font=f(POPPINS_BOLD, 25), fill=INK, anchor="ma", align="center", spacing=1)
    draw.text((1250, 1742), "Local content + offline graph + map tiles", font=f(POPPINS_BOLD, 26), fill=INK)
    draw.text((1250, 1788), "connect through a single mobile experience.", font=f(POPPINS, 25), fill=MUTED)

    # Column 3: verified product capabilities.
    section_heading(draw, 2220, 805, "03", "WHAT VISITORS CAN DO")
    feature(draw, 2235, 925, ORANGE, "DISCOVER", "Browse pagodas, search, filter and save favorites.")
    feature(draw, 2235, 1090, BLUE, "NAVIGATE", "Explore the interactive map and plan trips.")
    feature(draw, 2235, 1255, MINT, "TRAVEL OFFLINE", "Use cached tiles and bundled route data.")
    feature(draw, 2235, 1420, GOLD, "ASK FOR GUIDANCE", "Use the signed-in AI travel assistant.")
    draw.rounded_rectangle((2225, 1640, 3310, 1880), radius=28, fill="#EDF2F1", outline=LINE, width=3)
    draw.text((2270, 1680), "TECHNOLOGY", font=f(POPPINS_BOLD, 23), fill=ORANGE)
    draw.text((2270, 1730), "Flutter  |  Firebase  |  SQLite", font=f(POPPINS_BOLD, 28), fill=INK)
    draw.text((2270, 1780), "OpenStreetMap  |  A* routing", font=f(POPPINS_BOLD, 28), fill=INK)

    # Footer: academic details and a visible action point.
    draw.rectangle((0, 2050, W, H), fill=NAVY)
    draw.rectangle((0, 2050, W, 2072), fill=GOLD)
    draw.text((90, 2140), "PROJECT TEAM", font=f(POPPINS_BOLD, 24), fill="#F4C86B")
    draw.text((90, 2190), "Phyu Hnin Aung (Leader)  |  Kyaw Zay Ya Hein", font=f(POPPINS_BOLD, 31), fill=WHITE)
    draw.text((90, 2252), "Instructor: Dr. Myat Thuzar Tun  |  Supervisor: Daw Khin Myat Nwe Win", font=f(POPPINS, 25), fill="#C9D8DE")
    draw.text((90, 2310), "MIIT - Computer Science & Engineering  |  I Semester 2025-2026", font=f(POPPINS, 25), fill="#C9D8DE")

    code = qr_image().resize((300, 300), Image.Resampling.NEAREST)
    poster.paste(code, (3110, 2115))
    draw.text((2625, 2162), "SCAN TO EXPLORE", font=f(POPPINS_BOLD, 28), fill="#F4C86B")
    draw.text((2625, 2212), "Project source & demo", font=f(POPPINS_BOLD, 34), fill=WHITE)
    draw.text((2625, 2270), "github.com/SwordsoulOfLabyrinth", font=f(POPPINS, 21), fill="#C9D8DE")

    poster.save(PNG, dpi=(300, 300), quality=95, subsampling=0)
    page_w, page_h = landscape(A4)
    pdf = canvas.Canvas(str(PDF), pagesize=(page_w, page_h))
    pdf.setTitle("Baganetic - A4 Exhibition Board")
    pdf.drawImage(str(PNG), 0, 0, width=page_w, height=page_h)
    pdf.showPage()
    pdf.save()
    print(PNG)
    print(PDF)


if __name__ == "__main__":
    main()
