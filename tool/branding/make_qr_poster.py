#!/usr/bin/env python3
"""Genera la imagen con QR de descarga de la app FLY+.

Uso: make_qr_poster.py <url_corto> <salida.png> [texto_extra] [titulo] [subtitulo] [icono.png]
Requiere: pip install qrcode pillow
"""
import sys
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2] / "catalogos" / "assets"
NAVY, BLUE, CYAN, GREEN = "#001634", "#004aad", "#5de0e6", "#00ff94"
W, H = 1080, 1350


def font(weight, size):
    return ImageFont.truetype(str(ROOT / "fonts" / f"Poppins-{weight}.ttf"), size)


ICON = ROOT / "branding" / "play_store_icon_512.png"


def rounded_icon(size):
    ic = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size, size), size // 4, fill=255)
    ic.putalpha(m)
    return ic


def centered(d, y, text, f, fill):
    d.text(((W - d.textlength(text, font=f)) / 2, y), text, font=f, fill=fill)


def main(url, out, extra="", title="Descarga Flymas", subtitle="La app para revendedores", icon=""):
    global ICON
    if icon:
        ICON = Path(icon)
    img = Image.new("RGB", (W, H), NAVY)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((-300, -350, 700, 650), fill=(0, 74, 173, 150))
    g.ellipse((600, 900, 1400, 1700), fill=(93, 224, 230, 70))
    img.paste(glow, (0, 0), glow)
    d = ImageDraw.Draw(img)

    img.paste(rounded_icon(150), ((W - 150) // 2, 70), rounded_icon(150))
    centered(d, 245, title, font("Bold", 84), "white")
    if subtitle:
        centered(d, 350, subtitle, font("SemiBold", 40), CYAN)

    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, border=0, box_size=20)
    qr.add_data(url)
    qr.make(fit=True)
    q = qr.make_image(fill_color=NAVY, back_color="white").convert("RGB").resize((640, 640), Image.NEAREST)
    pad, card = 60, 640 + 120
    cx, cy = (W - card) // 2, 425
    d.rounded_rectangle((cx, cy, cx + card, cy + card), 56, fill="white")
    img.paste(q, (cx + pad, cy + pad))
    logo = 150
    lx, ly = (W - logo) // 2, cy + (card - logo) // 2
    d.rounded_rectangle((lx - 14, ly - 14, lx + logo + 14, ly + logo + 14), 40, fill="white")
    img.paste(rounded_icon(logo), (lx, ly), rounded_icon(logo))

    centered(d, 1195, "Escanea con la cámara de tu celular", font("Medium", 34), "white")
    pill = url.replace("https://", "").replace("http://", "")
    f = font("SemiBold", 40)
    tw = d.textlength(pill, font=f)
    px = (W - tw) / 2
    d.rounded_rectangle((px - 36, 1255, px + tw + 36, 1325), 35, outline=GREEN, width=3)
    d.text((px, 1262), pill, font=f, fill=GREEN)
    if extra:
        centered(d, 20, extra, font("Medium", 28), CYAN)
    img.save(out)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(*sys.argv[1:7])
