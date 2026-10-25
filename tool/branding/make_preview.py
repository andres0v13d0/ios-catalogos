#!/usr/bin/env python3
"""Genera assets/branding/preview.png: hoja de contacto con todas las
variaciones de marca FLY+ (icono adaptativo en mascaras circular/
cuadrada/squircle, monochrome, logo sobre blanco y oscuro, wordmark,
icon_only, notificacion, splash). Requiere haber corrido antes
prepare_fly_plus.py (lee sus salidas en assets/branding/)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[2]
B = REPO_ROOT / "catalogos" / "assets" / "branding"
OUT = B / "preview.png"

CARD = 300
PAD = 24
LABEL_H = 34
BG = (235, 238, 242)
CARD_BG = (255, 255, 255)
CARD_BG_DARK = (0, 22, 52)
COLS = 5


def font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def mask_shape(shape: str, size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    if shape == "circle":
        d.ellipse((0, 0, size, size), fill=255)
    elif shape == "square":
        d.rectangle((0, 0, size, size), fill=255)
    else:  # squircle aproximado
        d.rounded_rectangle((0, 0, size, size), radius=int(size * 0.33), fill=255)
    return m


def card(content: Image.Image, label: str, bg=CARD_BG) -> Image.Image:
    out = Image.new("RGB", (CARD, CARD + LABEL_H), BG)
    inner = Image.new("RGB", (CARD, CARD), bg)
    if content.mode == "RGBA":
        inner.paste(content, (0, 0), content)
    else:
        inner.paste(content, (0, 0))
    out.paste(inner, (0, 0))
    d = ImageDraw.Draw(out)
    f = font(16)
    bbox = d.textbbox((0, 0), label, font=f)
    tw = bbox[2] - bbox[0]
    d.text(((CARD - tw) // 2, CARD + 8), label, font=f, fill=(30, 34, 40))
    return out


def fit(path: Path, size: int, pad_frac: float = 0.12) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    target = int(size * (1 - pad_frac * 2))
    scale = target / max(im.size)
    im = im.resize((max(1, round(im.size[0] * scale)), max(1, round(im.size[1] * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(im, ((size - im.size[0]) // 2, (size - im.size[1]) // 2), im)
    return canvas


def masked_adaptive(shape: str) -> Image.Image:
    bg = Image.open(B / "icon_adaptive_1024.png").convert("RGBA").resize((CARD, CARD), Image.LANCZOS)
    m = mask_shape(shape, CARD)
    out = Image.new("RGBA", (CARD, CARD), (0, 0, 0, 0))
    out.paste(bg, (0, 0), m)
    return out


def main() -> None:
    cards: list[Image.Image] = []

    for shape, label in [("circle", "Adaptativo - circulo"), ("square", "Adaptativo - cuadrado"), ("squircle", "Adaptativo - squircle")]:
        cards.append(card(masked_adaptive(shape), label))

    cards.append(card(fit(B / "icon_flat_1024.png", CARD, 0), "Icono plano (legacy/iOS)"))
    cards.append(card(fit(B / "play_store_icon_512.png", CARD, 0), "Play Store 512"))

    mono_gray_bg = fit(B / "icon_monochrome_1024.png", CARD)
    cards.append(card(mono_gray_bg, "Monochrome / gris claro", bg=(205, 208, 214)))
    mono_dark_bg = fit(B / "icon_monochrome_1024.png", CARD)
    cards.append(card(mono_dark_bg, "Monochrome / oscuro", bg=CARD_BG_DARK))

    cards.append(card(fit(B / "icon_adaptive_1024_dev.png", CARD, 0), "Flavor dev"))
    cards.append(card(fit(B / "icon_adaptive_1024_staging.png", CARD, 0), "Flavor staging"))

    cards.append(card(fit(B / "fly_plus_logo_full.png", CARD), "Logo full / blanco", bg=CARD_BG))
    cards.append(card(fit(B / "fly_plus_logo_full.png", CARD), "Logo full / oscuro", bg=CARD_BG_DARK))
    cards.append(card(fit(B / "fly_plus_logo_white.png", CARD), "Logo blanco / oscuro", bg=CARD_BG_DARK))

    cards.append(card(fit(B / "fly_plus_icon_only.png", CARD), "Icon only / blanco", bg=CARD_BG))
    cards.append(card(fit(B / "fly_plus_icon_only_white.png", CARD), "Icon only blanco / oscuro", bg=CARD_BG_DARK))

    cards.append(card(fit(B / "fly_plus_wordmark.png", CARD), "Wordmark / blanco", bg=CARD_BG))
    cards.append(card(fit(B / "fly_plus_wordmark_white.png", CARD), "Wordmark blanco / oscuro", bg=CARD_BG_DARK))

    cards.append(card(fit(B / "fly_plus_logo_tile.png", CARD, 0), "Logo tile (redondeado)"))

    notif = fit(B / "ic_stat_notification_master.png", CARD)
    cards.append(card(notif, "Notificacion (silueta)", bg=CARD_BG_DARK))

    splash_preview = Image.new("RGBA", (CARD, CARD), (255, 255, 255, 255))
    sp = fit(B / "splash.png", CARD)
    splash_preview.paste(sp, (0, 0), sp)
    cards.append(card(splash_preview, "Splash (< Android 12)"))

    a12 = Image.new("RGBA", (CARD, CARD), (255, 255, 255, 255))
    a12_icon = fit(B / "icon_foreground.png", CARD)
    a12.paste(a12_icon, (0, 0), a12_icon)
    cards.append(card(a12, "Splash Android 12+ (icono)"))

    rows = (len(cards) + COLS - 1) // COLS
    sheet_w = COLS * CARD + (COLS + 1) * PAD
    sheet_h = rows * (CARD + LABEL_H) + (rows + 1) * PAD + 70
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    d = ImageDraw.Draw(sheet)
    title_f = font(28)
    d.text((PAD, 20), "FLY+ - Hoja de contacto de marca", font=title_f, fill=(10, 20, 40))

    for i, c in enumerate(cards):
        row, col = divmod(i, COLS)
        x = PAD + col * (CARD + PAD)
        y = 70 + PAD + row * (CARD + LABEL_H + PAD)
        sheet.paste(c, (x, y))

    sheet.save(OUT, format="PNG", optimize=True)
    print(f"{OUT.relative_to(REPO_ROOT)}  {sheet.size[0]}x{sheet.size[1]}  ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
