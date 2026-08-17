from pathlib import Path

from PIL import Image
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "deliverables" / "show-stand" / "Baganetic_Show_Stand_Reference_Match_A5_Landscape.png"
PNG_OUTPUT = ROOT / "deliverables" / "show-stand" / "Baganetic_Show_Stand_Theme_Matched_A4_Landscape_300dpi.png"
PDF_OUTPUT = ROOT / "output" / "pdf" / "Baganetic_Show_Stand_Theme_Matched_A4_Landscape.pdf"
A4_300_DPI = (3508, 2480)


def main() -> None:
    PNG_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    PDF_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(SOURCE) as source:
        # A5 and A4 share almost the same aspect ratio. Crop 4 px per side
        # before scaling, so the final print has exact ISO A4 proportions.
        image = source.convert("RGB")
        target_ratio = A4_300_DPI[0] / A4_300_DPI[1]
        crop_width = round(image.height * target_ratio)
        left = (image.width - crop_width) // 2
        image = image.crop((left, 0, left + crop_width, image.height))
        image = image.resize(A4_300_DPI, Image.Resampling.LANCZOS)
        image.save(PNG_OUTPUT, dpi=(300, 300), quality=95, subsampling=0)

    page_width, page_height = landscape(A4)
    pdf = canvas.Canvas(str(PDF_OUTPUT), pagesize=(page_width, page_height))
    pdf.setTitle("Baganetic - Theme-Matched A4 Landscape Exhibition Poster")
    pdf.drawImage(str(PNG_OUTPUT), 0, 0, width=page_width, height=page_height)
    pdf.showPage()
    pdf.save()

    print(PNG_OUTPUT)
    print(PDF_OUTPUT)


if __name__ == "__main__":
    main()
