from pathlib import Path

from PIL import Image
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "deliverables" / "show-stand" / "Baganetic_Show_Stand_English_A5_Landscape.png"
PNG_OUTPUT = ROOT / "deliverables" / "show-stand" / "Baganetic_Show_Stand_English_A4_Landscape_300dpi.png"
PDF_OUTPUT = ROOT / "output" / "pdf" / "Baganetic_Show_Stand_English_A4_Landscape.pdf"

# ISO A4 landscape at 300 DPI: 3508 x 2480 px.
A4_300_DPI = (3508, 2480)


def main() -> None:
    PNG_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    PDF_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(SOURCE) as source:
        poster = source.convert("RGB").resize(A4_300_DPI, Image.Resampling.LANCZOS)
        poster.save(PNG_OUTPUT, dpi=(300, 300), quality=95, subsampling=0)

    page_width, page_height = landscape(A4)
    pdf = canvas.Canvas(str(PDF_OUTPUT), pagesize=(page_width, page_height))
    pdf.setTitle("Baganetic - A4 Landscape Exhibition Poster")
    pdf.drawImage(str(PNG_OUTPUT), 0, 0, width=page_width, height=page_height, mask="auto")
    pdf.showPage()
    pdf.save()

    print(PNG_OUTPUT)
    print(PDF_OUTPUT)


if __name__ == "__main__":
    main()
