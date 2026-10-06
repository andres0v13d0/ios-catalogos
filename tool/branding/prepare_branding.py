#!/usr/bin/env python3
"""Prepara los assets de branding de FLYmovil a partir de los originales.

Lee:
  - <repo_root>/16.png  -> logo sobre fondo navy solido (fuente del icono)
  - <repo_root>/17.png  -> logo con fondo transparente (fuente del splash)

Escribe (sobrescribe) en <repo_root>/catalogos/assets/branding/:
  - icon.png            1024x1024, opaco, para iOS y como icono "legacy" Android
  - icon_foreground.png 1024x1024, fondo transparente, logo centrado al 60%
                         (safe zone del icono adaptativo de Android: 66% nominal,
                         se deja margen extra para no rozar el borde del circulo/mascara)
  - splash.png          1024x1024, fondo transparente, logo centrado al 60%
                         (Android 12+ recorta el splash en circulo: se usa el mismo
                         margen conservador que en el icono adaptativo)

No modifica ni borra los originales de la raiz. Re-ejecutable sin efectos
secundarios: siempre relee los originales y regenera los 3 archivos de salida.

Colores de fondo (decision, ver tool/branding/README.md para el detalle):
  - Icono adaptativo Android: #001634. El propio 16.png ya viene compuesto
    por la marca sobre ese navy (es el color primario de FlyStock, ver
    CLAUDE.md) y el cubo usa tonos teal/verde de luminancia media-alta, o
    sea "claro" sobre fondo oscuro: calza con la regla (logo claro -> #001634).
  - Splash: #FFFFFF, DISTINTO del icono. 17.png no es solo el cubo: es el
    lockup completo "FLYmovil", y la palabra "movil" esta renderizada en el
    MISMO navy #001634. Si el splash usara #001634 de fondo, "movil" quedaria
    invisible (texto navy sobre fondo navy). Se verifico comparando el render
    sobre navy vs. sobre blanco: solo sobre blanco el wordmark completo es
    legible. No es inconsistencia entre icono y splash: son dos archivos
    fuente con composiciones distintas, preparados por la marca para fondos
    distintos.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_ICON = REPO_ROOT / "16.png"
SRC_SPLASH = REPO_ROOT / "17.png"
OUT_DIR = REPO_ROOT / "catalogos" / "assets" / "branding"

BACKGROUND_COLOR = (0, 22, 52)  # #001634 -- fondo del icono (adaptive_icon_background)
BACKGROUND_HEX = "#001634"
SPLASH_BACKGROUND_HEX = "#FFFFFF"  # fondo del splash (distinto: ver docstring arriba)
CHROMA_TOLERANCE = 18  # por canal, para separar el logo del fondo solido en 16.png
ALPHA_THRESHOLD = 10  # para recortar al contenido real en imagenes con alpha

ICON_SIZE = 1024
SAFE_RATIO = 0.60  # el logo ocupa como maximo este % del lienzo (margen de seguridad)


def _fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def _validate_inputs() -> None:
    if not SRC_ICON.is_file():
        _fail(f"no existe {SRC_ICON}")
    if not SRC_SPLASH.is_file():
        _fail(f"no existe {SRC_SPLASH}")


def _content_bbox_by_chroma_key(im_rgba: Image.Image, bg: tuple[int, int, int], tol: int):
    """bbox del contenido que NO es el color de fondo (comparacion por bloques, rapido)."""
    w, h = im_rgba.size
    px = im_rgba.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    step = 1 if max(w, h) <= 512 else 2
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b, _a = px[x, y]
            if abs(r - bg[0]) > tol or abs(g - bg[1]) > tol or abs(b - bg[2]) > tol:
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
    if maxx < 0:
        return None
    return (minx, miny, maxx + 1, maxy + 1)


def _to_transparent_by_chroma_key(im_rgba: Image.Image, bg: tuple[int, int, int], tol: int) -> Image.Image:
    """Devuelve una copia con el color de fondo vuelto transparente."""
    out = im_rgba.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - bg[0]) <= tol and abs(g - bg[1]) <= tol and abs(b - bg[2]) <= tol:
                px[x, y] = (r, g, b, 0)
    return out


def _center_on_canvas(content: Image.Image, canvas_size: int, safe_ratio: float) -> Image.Image:
    """Escala `content` (RGBA ya recortado a su bbox) y lo centra en un lienzo
    cuadrado transparente, sin deformar, de forma que el lado mas largo ocupe
    `safe_ratio` del lienzo."""
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    cw, ch = content.size
    target = int(canvas_size * safe_ratio)
    scale = target / max(cw, ch)
    new_w, new_h = max(1, round(cw * scale)), max(1, round(ch * scale))
    resized = content.resize((new_w, new_h), Image.LANCZOS)
    offset = ((canvas_size - new_w) // 2, (canvas_size - new_h) // 2)
    canvas.paste(resized, offset, resized)
    return canvas


def make_icon_flat() -> Image.Image:
    """icon.png: 1024x1024, opaco, logo+fondo tal como lo definio la marca.
    Ya es cuadrado (2000x2000) asi que solo se reescala; si algun dia llega un
    original no cuadrado, se rellena con BACKGROUND_COLOR (nunca se estira)."""
    im = Image.open(SRC_ICON).convert("RGB")
    w, h = im.size
    if w != h:
        side = max(w, h)
        padded = Image.new("RGB", (side, side), BACKGROUND_COLOR)
        padded.paste(im, ((side - w) // 2, (side - h) // 2))
        im = padded
    return im.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)


def make_icon_foreground() -> Image.Image:
    """icon_foreground.png: logo de 16.png sin el fondo navy, centrado al 60%
    sobre un lienzo transparente de 1024x1024 (safe zone del icono adaptativo)."""
    im = Image.open(SRC_ICON).convert("RGBA")
    bbox = _content_bbox_by_chroma_key(im, BACKGROUND_COLOR, CHROMA_TOLERANCE)
    if bbox is None:
        _fail("16.png: no se pudo separar el logo del fondo (bbox vacio)")
    transparent = _to_transparent_by_chroma_key(im.crop(bbox), BACKGROUND_COLOR, CHROMA_TOLERANCE)
    return _center_on_canvas(transparent, ICON_SIZE, SAFE_RATIO)


def make_splash() -> Image.Image:
    """splash.png: logo de 17.png (ya tiene fondo transparente real), recortado
    a su contenido y centrado al 60% sobre un lienzo transparente de 1024x1024
    (margen conservador por el recorte en circulo del splash de Android 12+)."""
    im = Image.open(SRC_SPLASH).convert("RGBA")
    alpha_mask = im.split()[-1].point(lambda a: 255 if a > ALPHA_THRESHOLD else 0)
    bbox = alpha_mask.getbbox()
    if bbox is None:
        _fail("17.png: la imagen no tiene contenido con alpha (todo transparente)")
    content = im.crop(bbox)
    return _center_on_canvas(content, ICON_SIZE, SAFE_RATIO)


ANDROID12_BRANDING_SIZE = (800, 320)  # tamano fijo exigido por flutter_native_splash
ANDROID12_BRANDING_SAFE_RATIO = 0.85  # margen de seguridad dentro del lienzo 800x320


def _split_icon_and_wordmark(content: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Divide el contenido (ya recortado a su bbox) del lockup de 17.png en dos
    bloques verticales -- el cubo (arriba) y el wordmark "FLYmovil" (abajo) --
    ubicando el hueco horizontal sin contenido que los separa. No asume
    coordenadas fijas: vuelve a detectar el hueco cada vez, asi que sigue
    funcionando si cambia el original."""
    w, h = content.size
    px = content.load()
    row_has_content = []
    for y in range(h):
        has = any(px[x, y][3] > ALPHA_THRESHOLD for x in range(w))
        row_has_content.append(has)
    segments: list[tuple[int, int]] = []
    start = None
    for y, has in enumerate(row_has_content):
        if has and start is None:
            start = y
        if not has and start is not None:
            segments.append((start, y - 1))
            start = None
    if start is not None:
        segments.append((start, h - 1))
    if len(segments) < 2:
        _fail(
            "17.png: se esperaban 2 bloques (cubo + wordmark) separados por un "
            "hueco vertical y se encontro(n) "
            f"{len(segments)}; no se puede generar el branding de Android 12+"
        )
    icon_seg, wordmark_seg = segments[0], segments[-1]
    icon = content.crop((0, icon_seg[0], w, icon_seg[1] + 1))
    wordmark = content.crop((0, wordmark_seg[0], w, wordmark_seg[1] + 1))
    icon = icon.crop(icon.split()[-1].point(lambda a: 255 if a > ALPHA_THRESHOLD else 0).getbbox())
    wordmark = wordmark.crop(
        wordmark.split()[-1].point(lambda a: 255 if a > ALPHA_THRESHOLD else 0).getbbox()
    )
    return icon, wordmark


def make_android12_branding() -> Image.Image:
    """android12_branding.png: SOLO el wordmark "FLYmovil" (sin el cubo, que ya
    se muestra como icono animado) centrado sin deformar en el lienzo fijo de
    800x320 que exige `windowSplashScreenBrandingImage`, ocupando como maximo
    el 85% del lienzo (margen de seguridad, igual criterio que el resto de
    assets: nunca se recorta)."""
    im = Image.open(SRC_SPLASH).convert("RGBA")
    alpha_mask = im.split()[-1].point(lambda a: 255 if a > ALPHA_THRESHOLD else 0)
    bbox = alpha_mask.getbbox()
    if bbox is None:
        _fail("17.png: la imagen no tiene contenido con alpha (todo transparente)")
    content = im.crop(bbox)
    _icon, wordmark = _split_icon_and_wordmark(content)

    canvas_w, canvas_h = ANDROID12_BRANDING_SIZE
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    ww, wh = wordmark.size
    target_w = canvas_w * ANDROID12_BRANDING_SAFE_RATIO
    target_h = canvas_h * ANDROID12_BRANDING_SAFE_RATIO
    scale = min(target_w / ww, target_h / wh)
    new_w, new_h = max(1, round(ww * scale)), max(1, round(wh * scale))
    resized = wordmark.resize((new_w, new_h), Image.LANCZOS)
    offset = ((canvas_w - new_w) // 2, (canvas_h - new_h) // 2)
    canvas.paste(resized, offset, resized)
    return canvas


def _save_optimized(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def main() -> None:
    _validate_inputs()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Fondo icono (adaptive_icon_background): {BACKGROUND_HEX}")
    print(f"Fondo splash (flutter_native_splash color): {SPLASH_BACKGROUND_HEX} (distinto del icono: 'movil' esta en {BACKGROUND_HEX}, se veria invisible sobre ese mismo fondo)")

    icon = make_icon_flat()
    icon_path = OUT_DIR / "icon.png"
    _save_optimized(icon, icon_path)
    print(f"  icon.png            {icon.size[0]}x{icon.size[1]}  -> {icon_path}  ({icon_path.stat().st_size} bytes)")

    fg = make_icon_foreground()
    fg_path = OUT_DIR / "icon_foreground.png"
    _save_optimized(fg, fg_path)
    print(f"  icon_foreground.png {fg.size[0]}x{fg.size[1]}  -> {fg_path}  ({fg_path.stat().st_size} bytes)")

    splash = make_splash()
    splash_path = OUT_DIR / "splash.png"
    _save_optimized(splash, splash_path)
    print(f"  splash.png          {splash.size[0]}x{splash.size[1]}  -> {splash_path}  ({splash_path.stat().st_size} bytes)")

    android12_branding = make_android12_branding()
    android12_branding_path = OUT_DIR / "android12_branding.png"
    _save_optimized(android12_branding, android12_branding_path)
    print(
        f"  android12_branding.png {android12_branding.size[0]}x{android12_branding.size[1]}  "
        f"-> {android12_branding_path}  ({android12_branding_path.stat().st_size} bytes)"
    )

    print("\nListo. Originales en la raiz del repo intactos (16.png, 17.png).")


if __name__ == "__main__":
    main()
