#!/usr/bin/env python3
"""Genera los assets de marca FLY+ desde los SVG fuente. NUNCA usa
`fly-plus-source.png` (el PNG viejo), ni blur, ni feather, ni extension de
fondo, ni IA/rembg. Cada PNG se renderiza DIRECTO al tamano exacto que
necesita (resvg via node/render.js); cuando hace falta un recorte (zoom al
centro del SVG) se arma un SVG envoltorio con un viewBox mas chico y se
renderiza ese -- nunca se reescala un PNG ya generado.

Fuentes:
  assets/branding/fly-plus-launcher.svg   icono del launcher (432x432,
                                           lienzo adaptativo 108dp, opaco,
                                           degradado + cubos, SIN texto).
                                           Fuente UNICA del icono.
  assets/branding/svg/fly-plus.svg              logo + fondo degradado.
  assets/branding/svg/fly-plus-transparente.svg logo completo a color, sin fondo.
  assets/branding/svg/fly-plus-blanco.svg       logo completo, blanco.
  assets/branding/svg/fly-plus-icono.svg        cubos + lineas, sin texto.
  assets/branding/svg/fly-plus-texto.svg        solo "FLY+".
  assets/branding/svg/fly-plus-notificacion.svg solo cubos, blanco.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[2]
CATALOGOS = REPO_ROOT / "catalogos"
OUT = CATALOGOS / "assets" / "branding"
SVG_DIR = OUT / "svg"
ANDROID_RES = CATALOGOS / "android" / "app" / "src" / "main" / "res"
NODE_RENDER = REPO_ROOT / "tool" / "branding" / "node" / "render.js"
TMP = Path("/tmp/fly_plus_render")

SVG_LAUNCHER = OUT / "fly-plus-launcher.svg"
SVG_FULL = SVG_DIR / "fly-plus.svg"
SVG_TRANSPARENT = SVG_DIR / "fly-plus-transparente.svg"
SVG_ICON = SVG_DIR / "fly-plus-icono.svg"
SVG_TEXT = SVG_DIR / "fly-plus-texto.svg"
SVG_WHITE = SVG_DIR / "fly-plus-blanco.svg"
SVG_NOTIF = SVG_DIR / "fly-plus-notificacion.svg"

BG_GRADIENT_STOPS = [
    (0, "#0206F4"), (0.3, "#012FFE"), (0.55, "#0175FF"), (0.8, "#02C0FD"), (1, "#03FBFC"),
]
LAUNCHER_BG_COLOR = "#0A4DFF"
SPLASH_BG_COLOR = "#001d44"

NOTIF_SAFE = 0.92
BRANDING_SAFE = 0.85
LEGACY_CROP = 0.66   # ic_launcher / ic_launcher_round: zoom al 66% central
STORE_CROP = 0.75    # Play Store 512 / iOS 1024: zoom al 75% central

ANDROID_DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
MIPMAP_DP = 48
ADAPTIVE_DP = 108
NOTIFICATION_DP = 24

FLAVOR_BADGES = {"dev": ("DEV", (255, 140, 0)), "staging": ("STG", (139, 92, 246))}
IOS_APPICONSETS = ["AppIcon", "AppIcon-dev", "AppIcon-staging", "AppIcon-prod"]

for p in [SVG_LAUNCHER, SVG_FULL, SVG_TRANSPARENT, SVG_ICON, SVG_TEXT, SVG_WHITE, SVG_NOTIF, NODE_RENDER]:
    if not p.is_file():
        print(f"ERROR: no existe {p}", file=sys.stderr)
        sys.exit(1)

_viewbox_cache: dict[Path, tuple[float, float, float, float]] = {}


def viewbox(svg_path: Path) -> tuple[float, float, float, float]:
    if svg_path not in _viewbox_cache:
        txt = svg_path.read_text()
        m = re.search(r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"', txt)
        _viewbox_cache[svg_path] = tuple(float(x) for x in m.groups())  # type: ignore[assignment]
    return _viewbox_cache[svg_path]


_inner_cache: dict[Path, str] = {}


def inner_svg(svg_path: Path) -> str:
    if svg_path not in _inner_cache:
        txt = svg_path.read_text()
        m = re.search(r"<svg[^>]*>(.*)</svg>", txt, re.DOTALL)
        _inner_cache[svg_path] = m.group(1)
    return _inner_cache[svg_path]


_render_counter = [0]


def render_svg(svg_path: Path, *, width: int | None = None, height: int | None = None) -> Image.Image:
    TMP.mkdir(parents=True, exist_ok=True)
    _render_counter[0] += 1
    out_path = TMP / f"r{_render_counter[0]}.png"
    cmd = ["node", str(NODE_RENDER), str(svg_path), str(out_path)]
    cmd += ["--width", str(width)] if width else ["--height", str(height)]
    subprocess.run(cmd, check=True, capture_output=True, text=True)
    im = Image.open(out_path).convert("RGBA")
    im.load()
    out_path.unlink()
    return im


def opaque(svg_path: Path, size: int) -> Image.Image:
    return render_svg(svg_path, width=size).convert("RGB")


def render_cropped(svg_path: Path, crop_frac: float, size: int) -> Image.Image:
    """Renderiza directo el recorte central (`crop_frac` del viewBox
    original) de `svg_path` a `size`x`size`, armando un SVG envoltorio con
    un viewBox mas chico (zoom vectorial real, no un resize de PNG)."""
    minx, miny, w, h = viewbox(svg_path)
    cw, ch = w * crop_frac, h * crop_frac
    cx, cy = minx + (w - cw) / 2, miny + (h - ch) / 2
    wrapper = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{cx} {cy} {cw} {ch}" '
        f'width="{cw}" height="{ch}">{inner_svg(svg_path)}</svg>'
    )
    TMP.mkdir(parents=True, exist_ok=True)
    _render_counter[0] += 1
    tmp_svg = TMP / f"crop{_render_counter[0]}.svg"
    tmp_svg.write_text(wrapper)
    im = render_svg(tmp_svg, width=size)
    tmp_svg.unlink()
    if im.size != (size, size):
        im = im.crop((0, 0, size, size))
    return im.convert("RGB")


def fit_width(svg_path: Path, canvas_w: int, canvas_h: int, width_frac: float) -> Image.Image:
    final_w = max(1, round(canvas_w * width_frac))
    content = render_svg(svg_path, width=final_w)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    canvas.paste(content, ((canvas_w - content.width) // 2, (canvas_h - content.height) // 2), content)
    return canvas


def fit_height(svg_path: Path, canvas_w: int, canvas_h: int, height_frac: float) -> Image.Image:
    final_h = max(1, round(canvas_h * height_frac))
    content = render_svg(svg_path, height=final_h)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    canvas.paste(content, ((canvas_w - content.width) // 2, (canvas_h - content.height) // 2), content)
    return canvas


def fit_content(svg_path: Path, canvas_w: int, canvas_h: int, frac: float) -> Image.Image:
    _, _, vb_w, vb_h = viewbox(svg_path)
    scale = min(canvas_w * frac / vb_w, canvas_h * frac / vb_h)
    final_w = max(1, round(vb_w * scale))
    content = render_svg(svg_path, width=final_w)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    canvas.paste(content, ((canvas_w - content.width) // 2, (canvas_h - content.height) // 2), content)
    return canvas


def gradient_png(w: int, h: int) -> Image.Image:
    stops = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in BG_GRADIENT_STOPS)
    svg_text = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">'
        f'<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="0.25">{stops}</linearGradient></defs>'
        f'<rect width="{w}" height="{h}" fill="url(#bg)"/></svg>'
    )
    TMP.mkdir(parents=True, exist_ok=True)
    tmp_svg = TMP / f"grad_{w}x{h}.svg"
    tmp_svg.write_text(svg_text)
    im = render_svg(tmp_svg, width=w).convert("RGB")
    tmp_svg.unlink()
    return im


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def add_flavor_badge(im: Image.Image, label: str, color: tuple[int, int, int]) -> Image.Image:
    out = im.convert("RGBA").copy()
    w, h = out.size
    pill_w, pill_h = int(w * 0.5), int(h * 0.15)
    cx, cy = w // 2, int(h * 0.82)
    box = (cx - pill_w // 2, cy - pill_h // 2, cx + pill_w // 2, cy + pill_h // 2)
    overlay = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.rounded_rectangle(box, radius=pill_h // 2, fill=(*color, 255))
    f = font(int(pill_h * 0.62))
    bbox = d.textbbox((0, 0), label, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]), label, font=f, fill=(255, 255, 255, 255))
    out.alpha_composite(overlay)
    return out


def rounded_mask(size: int, radius: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return m


def circle_mask(size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size, size), fill=255)
    return m


def apply_mask(im_rgb: Image.Image, mask: Image.Image) -> Image.Image:
    out = Image.new("RGBA", im_rgb.size, (0, 0, 0, 0))
    out.paste(im_rgb, (0, 0), mask)
    return out


# ---------------------------------------------------------------------------
# Limpieza total: nada del proceso viejo sobrevive
# ---------------------------------------------------------------------------

def delete_old_icon_resources() -> None:
    patterns = [
        "ic_launcher*.png", "ic_launcher.xml",
        "ic_launcher_foreground*.png", "ic_launcher_background*.png",
        "ic_launcher_round*.png", "ic_launcher_monochrome*.png",
    ]
    for flavor_dir in ["main", "dev", "staging"]:
        res = CATALOGOS / "android" / "app" / "src" / flavor_dir / "res"
        if not res.is_dir():
            continue
        for sub in list(res.glob("mipmap-*")) + list(res.glob("drawable-*")):
            for pat in patterns:
                for f in sub.glob(pat):
                    f.unlink()
        xml = res / "mipmap-anydpi-v26" / "ic_launcher.xml"
        if xml.is_file():
            xml.unlink()

    for name in IOS_APPICONSETS:
        d = CATALOGOS / "ios" / "Runner" / "Assets.xcassets" / f"{name}.appiconset"
        if d.is_dir():
            for f in d.glob("*.png"):
                f.unlink()

    for f in OUT.glob("icon_*.png"):
        f.unlink()
    pse = OUT / "play_store_icon_512.png"
    if pse.is_file():
        pse.unlink()


# ---------------------------------------------------------------------------
# Android launcher
# ---------------------------------------------------------------------------

def set_adaptive_background_color() -> None:
    colors_xml = ANDROID_RES / "values" / "colors.xml"
    colors_xml.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">{LAUNCHER_BG_COLOR}</color>\n'
        '</resources>\n'
    )


def build_android_launcher() -> None:
    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <background android:drawable="@color/ic_launcher_background"/>\n'
        '  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '  <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n'
    )
    set_adaptive_background_color()

    for flavor in (None, "dev", "staging"):
        res_dir = ANDROID_RES if flavor is None else CATALOGOS / "android" / "app" / "src" / flavor / "res"
        badge = FLAVOR_BADGES.get(flavor) if flavor else None

        xml_path = res_dir / "mipmap-anydpi-v26" / "ic_launcher.xml"
        xml_path.parent.mkdir(parents=True, exist_ok=True)
        xml_path.write_text(adaptive_xml)

        for density, mult in ANDROID_DENSITIES.items():
            mip_px = round(MIPMAP_DP * mult)

            legacy_sq = render_cropped(SVG_LAUNCHER, LEGACY_CROP, mip_px)
            legacy = apply_mask(legacy_sq, rounded_mask(mip_px, int(mip_px * 0.18)))
            if badge:
                legacy = add_flavor_badge(legacy, *badge)
            save(legacy, res_dir / f"mipmap-{density}" / "ic_launcher.png")

            round_icon = apply_mask(legacy_sq, circle_mask(mip_px))
            if badge:
                round_icon = add_flavor_badge(round_icon, *badge)
            save(round_icon, res_dir / f"mipmap-{density}" / "ic_launcher_round.png")

            ad_px = round(ADAPTIVE_DP * mult)
            fg = opaque(SVG_LAUNCHER, ad_px).convert("RGBA")
            if badge:
                fg = add_flavor_badge(fg, *badge)
            save(fg, res_dir / f"drawable-{density}" / "ic_launcher_foreground.png")

            mono = fit_height(SVG_NOTIF, ad_px, ad_px, 0.60)
            save(mono, res_dir / f"drawable-{density}" / "ic_launcher_monochrome.png")

    save(render_cropped(SVG_LAUNCHER, STORE_CROP, 512), OUT / "play_store_icon_512.png")


def build_notification() -> None:
    for density, mult in ANDROID_DENSITIES.items():
        px = round(NOTIFICATION_DP * mult)
        im = fit_content(SVG_NOTIF, px, px, NOTIF_SAFE)
        save(im, ANDROID_RES / f"drawable-{density}" / "ic_stat_notification.png")
    save(fit_content(SVG_NOTIF, 192, 192, NOTIF_SAFE), OUT / "ic_stat_notification_master.png")


def build_ios_appicon(name: str) -> None:
    appiconset_dir = CATALOGOS / "ios" / "Runner" / "Assets.xcassets" / f"{name}.appiconset"
    contents_path = appiconset_dir / "Contents.json"
    if not contents_path.is_file():
        return
    contents = json.loads(contents_path.read_text())
    for img in contents["images"]:
        scale = int(img["scale"].rstrip("x"))
        w_pt, h_pt = (float(x) for x in img["size"].split("x"))
        filename = img.get("filename")
        if not filename:
            continue
        save(render_cropped(SVG_LAUNCHER, STORE_CROP, round(w_pt * scale)), appiconset_dir / filename)


# ---------------------------------------------------------------------------
# Splash: color solido en TODO lado, sin degradado
# ---------------------------------------------------------------------------

def build_splash() -> None:
    save(fit_width(SVG_TRANSPARENT, 1024, 1024, 0.60), OUT / "splash.png")
    save(fit_content(SVG_ICON, 1024, 1024, 0.64), OUT / "icon_foreground.png")
    save(fit_content(SVG_TEXT, 800, 320, BRANDING_SAFE), OUT / "android12_branding.png")

    splash_yaml = CATALOGOS / "flutter_native_splash.yaml"
    splash_yaml.write_text(
        f"# Splash FLY+: color solido {SPLASH_BG_COLOR} (azul marino) en TODO --\n"
        "# splash nativo (Android <12 y 12+, claro y modo noche), splash de\n"
        "# Flutter y color de la ventana inicial. Sin degradado en ningun lado.\n"
        "# Logo completo a color (fly-plus-transparente.svg) al 60% del ancho,\n"
        "# centrado, sin deformar. Ver tool/branding/prepare_fly_plus.py.\n"
        "flutter_native_splash:\n"
        f'  color: "{SPLASH_BG_COLOR}"\n'
        f'  color_dark: "{SPLASH_BG_COLOR}"\n'
        "  image: assets/branding/splash.png\n"
        "  image_dark: assets/branding/splash.png\n"
        "\n"
        "  android_12:\n"
        "    image: assets/branding/icon_foreground.png\n"
        "    image_dark: assets/branding/icon_foreground.png\n"
        f'    color: "{SPLASH_BG_COLOR}"\n'
        f'    color_dark: "{SPLASH_BG_COLOR}"\n'
        f'    icon_background_color: "{SPLASH_BG_COLOR}"\n'
        f'    icon_background_color_dark: "{SPLASH_BG_COLOR}"\n'
        "    branding: assets/branding/android12_branding.png\n"
        "    branding_dark: assets/branding/android12_branding.png\n"
        "\n"
        "  android: true\n"
        "  ios: true\n"
        "  web: false\n"
    )


# ---------------------------------------------------------------------------
# Web, OG, feature graphic, assets sueltos de la app
# ---------------------------------------------------------------------------

def build_web() -> None:
    web_dir = CATALOGOS / "web"
    if not web_dir.is_dir():
        return
    save(opaque(SVG_FULL, 32), web_dir / "favicon.png")
    for size in (192, 512):
        save(opaque(SVG_FULL, size), web_dir / "icons" / f"Icon-{size}.png")
        canvas = gradient_png(size, size).convert("RGBA")
        canvas.alpha_composite(fit_content(SVG_TRANSPARENT, size, size, 0.66))
        save(canvas.convert("RGB"), web_dir / "icons" / f"Icon-maskable-{size}.png")


def build_social_graphics() -> None:
    for w, h, frac, name in [(1200, 630, 0.55, "og_image_1200x630.png"), (1024, 500, 0.5, "play_feature_graphic_1024x500.png")]:
        canvas = gradient_png(w, h).convert("RGBA")
        canvas.alpha_composite(fit_content(SVG_TRANSPARENT, w, h, frac))
        save(canvas.convert("RGB"), OUT / name)


def build_app_assets() -> None:
    def save_scaled(svg_path: Path, base_name: str, height_1x: int) -> None:
        _, _, vb_w, vb_h = viewbox(svg_path)
        for mult, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
            h = height_1x * mult
            w = max(1, round(vb_w * (h / vb_h)))
            save(render_svg(svg_path, width=w), OUT / f"{base_name}{suffix}.png")

    save_scaled(SVG_TRANSPARENT, "fly_plus_logo_full", 96)
    save_scaled(SVG_WHITE, "fly_plus_logo_white", 96)
    save_scaled(SVG_ICON, "fly_plus_icon_only", 96)
    save_scaled(SVG_NOTIF, "fly_plus_icon_only_white", 96)
    save_scaled(SVG_TEXT, "fly_plus_wordmark", 48)

    for mult, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
        size = 128 * mult
        rgba = apply_mask(opaque(SVG_FULL, size), rounded_mask(size, int(size * 0.22)))
        save(rgba, OUT / f"fly_plus_logo_tile{suffix}.png")


# ---------------------------------------------------------------------------
# Hoja de contacto (unico vistazo de control, para que el usuario confirme)
# ---------------------------------------------------------------------------

def build_preview() -> None:
    CARD, PAD, LABEL_H = 260, 20, 30
    BG, CARD_LIGHT, CARD_DARK = (235, 238, 242), (255, 255, 255), (0, 22, 52)

    def fcard(content: Image.Image, label: str, bg=CARD_LIGHT) -> Image.Image:
        out = Image.new("RGB", (CARD, CARD + LABEL_H), BG)
        inner = Image.new("RGB", (CARD, CARD), bg)
        if content.mode == "RGBA":
            inner.paste(content, (0, 0), content)
        else:
            inner.paste(content.resize((CARD, CARD)) if content.size != (CARD, CARD) else content, (0, 0))
        out.paste(inner, (0, 0))
        d = ImageDraw.Draw(out)
        f = font(14)
        bbox = d.textbbox((0, 0), label, font=f)
        d.text(((CARD - (bbox[2] - bbox[0])) // 2, CARD + 6), label, font=f, fill=(30, 34, 40))
        return out

    adaptive_full = opaque(SVG_LAUNCHER, CARD).convert("RGBA")
    cards = [
        fcard(apply_mask(adaptive_full.convert("RGB"), circle_mask(CARD)), "Adaptativo - circulo"),
        fcard(adaptive_full, "Adaptativo - cuadrado"),
        fcard(apply_mask(adaptive_full.convert("RGB"), rounded_mask(CARD, int(CARD * 0.22))), "Adaptativo - squircle"),
        fcard(render_cropped(SVG_LAUNCHER, LEGACY_CROP, CARD), "Legacy (recorte 66%)"),
        fcard(apply_mask(render_cropped(SVG_LAUNCHER, LEGACY_CROP, CARD), circle_mask(CARD)), "Round"),
        fcard(render_cropped(SVG_LAUNCHER, STORE_CROP, CARD), "Play Store / iOS (recorte 75%)"),
        fcard(add_flavor_badge(adaptive_full, *FLAVOR_BADGES["dev"]), "Flavor dev"),
        fcard(add_flavor_badge(adaptive_full, *FLAVOR_BADGES["staging"]), "Flavor staging"),
        fcard(fit_height(SVG_NOTIF, CARD, CARD, 0.60), "Monochrome", bg=CARD_DARK),
        fcard(fit_content(SVG_NOTIF, CARD, CARD, NOTIF_SAFE), "Notificacion", bg=CARD_DARK),
        fcard(fit_width(SVG_TRANSPARENT, CARD, CARD, 0.60), "Logo / splash (claro)", bg=(255, 255, 255)),
        fcard(fit_width(SVG_TRANSPARENT, CARD, CARD, 0.60), "Logo / splash (oscuro #001d44)", bg=(0, 29, 68)),
        fcard(fit_content(SVG_WHITE, CARD, CARD, 0.6), "Logo blanco / oscuro", bg=CARD_DARK),
        fcard(fit_content(SVG_ICON, CARD, CARD, 0.64), "Splash Android 12+ (icono)", bg=(0, 29, 68)),
    ]

    cols = 5
    rows = (len(cards) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * CARD + (cols + 1) * PAD, rows * (CARD + LABEL_H) + (rows + 1) * PAD + 50), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 15), "FLY+ - assets regenerados desde SVG", font=font(24), fill=(10, 20, 40))
    for i, c in enumerate(cards):
        r, col = divmod(i, cols)
        sheet.paste(c, (PAD + col * (CARD + PAD), 50 + PAD + r * (CARD + LABEL_H + PAD)))
    save(sheet, OUT / "preview.png")


def main() -> None:
    delete_old_icon_resources()
    build_android_launcher()
    build_notification()
    for name in IOS_APPICONSETS:
        build_ios_appicon(name)
    build_splash()
    build_web()
    build_social_graphics()
    build_app_assets()
    build_preview()
    print("Listo.")


if __name__ == "__main__":
    main()
