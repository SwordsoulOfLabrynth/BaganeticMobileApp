"""Replace the poster mock-ups with the supplied, current Baganetic captures.

The existing A4 poster remains the visual source of truth.  This export only
replaces the three framed phone displays, preserving the approved typography,
feature copy, QR code, and footer.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
TELEGRAM = Path(r"C:\Users\Kyaw Zay Ya Hein\Downloads\Telegram Desktop")
SOURCE = ROOT / "deliverables" / "show-stand" / "Baganetic_Show_Stand_Theme_Matched_A4_Landscape_300dpi.png"
PNG_OUTPUT = ROOT / "deliverables" / "show-stand" / "Baganetic_Show_Stand_Actual_Screens_A4_Landscape_300dpi.png"
PDF_OUTPUT = ROOT / "output" / "pdf" / "Baganetic_Show_Stand_Actual_Screens_A4_Landscape.pdf"

# Screens are arranged in the same story order as the poster: map, pagodas,
# then home.  They are direct screenshots rather than pitch-slide crops.
MAP_CAPTURE = TELEGRAM / "Screenshot_20260818_114257.jpg"
PAGODAS_CAPTURE = TELEGRAM / "Screenshot_20260818_113003.jpg"
HOME_CAPTURE = TELEGRAM / "Screenshot_20260818_112607.jpg"

FRAME = "#21170F"
FRAME_EDGE = "#805431"


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Fill a phone screen while retaining its central, app-visible content."""
    width, height = size
    scale = max(width / image.width, height / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - width) // 2
    top = max(0, min(resized.height - height, round((resized.height - height) * 0.08)))
    return resized.crop((left, top, left + width, top + height))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *size), radius=radius, fill=255)
    return mask


def paste_phone(
    poster: Image.Image,
    position: tuple[int, int],
    size: tuple[int, int],
    capture_path: Path,
) -> None:
    """Draw a physical frame, then place a complete supplied capture inside it."""
    x, y = position
    width, height = size
    inset = 18
    radius = 78

    with Image.open(capture_path) as capture:
        screen = cover(capture.convert("RGB"), (width - inset * 2, height - inset * 2))

    shadow = Image.new("RGBA", (width + 70, height + 70), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (35, 35, width + 18, height + 18),
        radius=radius,
        fill=(43, 24, 13, 115),
    )
    poster.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)), (x - 24, y - 10))

    draw = ImageDraw.Draw(poster)
    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=radius,
        fill=FRAME,
        outline=FRAME_EDGE,
        width=7,
    )
    poster.paste(
        screen,
        (x + inset, y + inset),
        rounded_mask((width - inset * 2, height - inset * 2), radius - inset),
    )


def main() -> None:
    required = (SOURCE, MAP_CAPTURE, PAGODAS_CAPTURE, HOME_CAPTURE)
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing poster source or supplied capture:\n" + "\n".join(missing))

    PNG_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    PDF_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    # Frames deliberately overlap the original mock-ups completely.  Back-to-
    # front painting preserves the existing poster's depth hierarchy.
    with Image.open(SOURCE) as source:
        poster = source.convert("RGBA")
    paste_phone(poster, (1710, 555), (570, 1260), MAP_CAPTURE)
    # This taller centre frame also fully covers the older, taller mock-up
    # beneath it; no obsolete app pixels remain visible above the footer.
    paste_phone(poster, (2210, 175), (760, 1900), PAGODAS_CAPTURE)
    paste_phone(poster, (2910, 575), (570, 1260), HOME_CAPTURE)

    poster.convert("RGB").save(PNG_OUTPUT, dpi=(300, 300), quality=95, subsampling=0)

    page_width, page_height = landscape(A4)
    pdf = canvas.Canvas(str(PDF_OUTPUT), pagesize=(page_width, page_height))
    pdf.setTitle("Baganetic - A4 Exhibition Poster with Actual App Screens")
    pdf.drawImage(str(PNG_OUTPUT), 0, 0, width=page_width, height=page_height)
    pdf.showPage()
    pdf.save()

    print(PNG_OUTPUT)
    print(PDF_OUTPUT)


if __name__ == "__main__":
    main()
