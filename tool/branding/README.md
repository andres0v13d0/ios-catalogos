# Branding FLYmovil — cómo regenerar

## Qué hace

`prepare_branding.py` (o el wrapper `prepare_branding.sh`) lee los dos
originales de la raíz del repo y genera los 3 assets que consumen
`flutter_launcher_icons` y `flutter_native_splash`:

| Origen | Salida | Uso |
|---|---|---|
| `16.png` (logo sobre fondo navy sólido) | `catalogos/assets/branding/icon.png` | Ícono iOS y Android "legacy", 1024×1024, opaco |
| `16.png` (mismo, sin el fondo) | `catalogos/assets/branding/icon_foreground.png` | Foreground del ícono adaptativo Android, 1024×1024, fondo transparente, logo al 60% (safe zone) |
| `17.png` (lockup "FLYmovil" ya sin fondo) | `catalogos/assets/branding/splash.png` | Imagen del splash, 1024×1024, fondo transparente, contenido al 60% |

Nunca toca ni borra `16.png`/`17.png`. Es idempotente: cada corrida vuelve a
leer los originales y sobrescribe solo los 3 archivos de salida.

## Cómo regenerar (si cambian los originales)

Reemplaza `16.png` y/o `17.png` en la raíz del repo (mismo nombre, mismo
sitio) y corre:

```bash
./tool/branding/prepare_branding.sh
```

o directamente:

```bash
python3 tool/branding/prepare_branding.py
```

Requiere Python 3 + Pillow (ya está instalado en este entorno; si falta:
`pip install Pillow`). No requiere ImageMagick ni ninguna herramienta de
sistema adicional.

Después de regenerar, vuelve a correr:

```bash
cd catalogos
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Decisiones de color (con evidencia, no a ojo)

- **Fondo del ícono adaptativo Android (`#001634`):** `16.png` ya viene
  compuesto por la marca sobre ese navy — es el color primario de la
  identidad FlyStock (ver `CLAUDE.md`). El cubo del logo usa tonos
  teal/verde de luminancia media-alta: es un logo "claro" sobre fondo
  oscuro, que es exactamente la regla pedida.
- **Fondo del splash (`#FFFFFF`), DISTINTO del ícono:** `17.png` no es solo
  el cubo, es el lockup completo **"FLYmovil"**, y la palabra **"movil"**
  está renderizada en el mismo navy `#001634` que el fondo del ícono. Se
  comprobó componiendo `splash.png` sobre navy vs. sobre blanco: sobre
  navy, "movil" desaparece (texto navy sobre fondo navy); sobre blanco,
  todo el wordmark y el cubo son legibles. No es una inconsistencia entre
  ambos assets: son dos archivos fuente con composiciones distintas,
  pensados por la marca para fondos distintos.

## Safe zones

- **Ícono adaptativo:** el contenido se centra ocupando como máximo el 60%
  del lienzo de 1024×1024 (el estándar de Android pide no pasar del 66%;
  se dejó margen extra porque el logo original ya llegaba al 62-65%,
  justo al límite).
- **Splash:** mismo margen del 60%, porque en Android 12+ el sistema
  recorta la imagen del splash en un círculo — un margen generoso evita
  que algo se corte sin importar el launcher/dispositivo.

## Limitación conocida de optimización de peso

Solo se usó Pillow (`optimize=True` al guardar PNG) porque es lo único
instalado en este entorno — no hay `pngquant`/`oxipng`/`optipng`/
ImageMagick disponibles. Si se quiere una compresión más agresiva sin
pérdida, avisar antes de instalar algo con privilegios de sistema.
