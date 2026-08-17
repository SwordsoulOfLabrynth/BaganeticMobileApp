"""Export the supplied reference design unchanged inside an A5 print canvas."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = Path(r"C:\Users\KYAWZA~1\AppData\Local\Temp\codex-clipboard-882cf05f-b371-4f91-89b9-f4c821c5b580.png")
OUT = ROOT / "deliverables" / "show-stand" / "Baganetic_Reference_Unchanged_A5_Landscape.png"

# The reference's actual card, excluding the acrylic stand/photograph.
reference = Image.open(REFERENCE).convert("RGB")
card = reference.crop((40, 53, 1240, 610))

# Finished A5 landscape: 210 x 148 mm at 300 ppi. Contain, rather than crop or
# distort, so every part of the approved reference design remains unchanged.
canvas = Image.new("RGB", (2480, 1748), card.getpixel((10, 10)))
art = card.resize((2480, 1151), Image.Resampling.LANCZOS)
canvas.paste(art, (0, (1748 - 1151) // 2))
canvas.save(OUT, dpi=(300, 300), quality=95)
print(OUT)
