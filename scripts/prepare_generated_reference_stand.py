"""Pad the selected generated stand artwork to A5 landscape at 300 ppi."""

from pathlib import Path
from PIL import Image


source = Path(r"C:\Users\Kyaw Zay Ya Hein\.codex\generated_images\01a010ca-17b4-7273-9a2f-484a19d7cc7c\exec-e4ec29f2-e126-44cc-aec6-b0a04f6a4b87.png")
target = Path(__file__).resolve().parents[1] / "deliverables" / "show-stand" / "Baganetic_Show_Stand_Reference_Match_A5_Landscape.png"

# 2480 x 1748 px is A5 landscape at 300 ppi. Preserve the full 3:2 composition
# and add only narrow, matching cream top/bottom margins rather than cropping it.
canvas = Image.new("RGB", (2480, 1748), "#FFF8E9")
art = Image.open(source).convert("RGB").resize((2480, 1653), Image.Resampling.LANCZOS)
canvas.paste(art, (0, 47))
canvas.save(target, dpi=(300, 300), quality=95)
print(target)
