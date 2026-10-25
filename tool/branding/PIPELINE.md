# Pipeline de marca FLY+

Fuente unica: `catalogos/assets/branding/fly-plus-source.png` (1254x1254,
opaca — pese a la extension `.png` el archivo es en realidad un JPEG
progresivo sin canal alfa, logo sobre degradado azul -> cian, sin version
separada del fondo).

Scripts (`tool/branding/`):
- `prepare_fly_plus.py` — genera todos los PNG en `assets/branding/` y los
  `ic_stat_notification.png` por densidad en `android/app/src/main/res/`.
- `make_preview.py` — arma `assets/branding/preview.png` (hoja de contacto).

Regenerar todo tras cambiar el logo fuente:

```bash
cd catalogos
python3 ../tool/branding/prepare_fly_plus.py
python3 ../tool/branding/make_preview.py
dart run flutter_launcher_icons   # procesa flutter_launcher_icons-{prod,dev,staging}.yaml
dart run flutter_native_splash:create
```

## Por que no se uso IA (rembg) para separar el logo del fondo

El pedido explicito era no usar remocion de fondo por IA. Se probaron dos
tecnicas, ambas deterministicas:

1. **Reconstruccion del fondo por difusion** (inpainting clasico: mascara
   de contenido -> difusion restringida por blur iterativo multi-resolucion
   -> alfa por diferencia). Funciona en teoria, pero el degradado real no
   es bilineal/radial simple y la reconstruccion no convergia limpio en el
   tiempo disponible (quedaban "fantasmas" del logo); se descarto.
2. **Mascara binaria de contenido** (contraste local + deteccion de bordes,
   cierre morfologico, relleno de huecos por flood-fill desde las esquinas
   del lienzo, apertura chica para quitar motas) + blur de ~1px para
   antialiasing. Esta es la que se uso en todo el pipeline para los
   recortes con transparencia (monochrome, notificacion, logo/icono/
   wordmark sueltos). Umbrales calibrados a mano (edges>22, local-range>60)
   para que no se cuelen las sombras suaves bajo los cubos/texto (con
   umbrales mas bajos el borde quedaba dentado).

Para el **icono opaco** (launcher, adaptativo, Play Store, iOS, favicon, OG,
feature graphic) no hace falta separar nada: se encoge el logo completo
(con su fondo) y el margen se rellena replicando los pixeles del borde de
la imagen encogida + blur fuerte (radius 45) + mascara de union con blur
muy ancho (radius 100, inset 60). La replicacion de borde dejaba una
transicion con pendiente cero mientras el degradado real sigue cambiando
("Mach band" perceptual); a 1024px muy zoomeado se alcanza a notar un
anillo tenue, pero a los tamanos reales de icono (<=192px, verificado por
inspeccion visual) es imperceptible.

## Zona segura / recortes

- Icono adaptativo: contenido escalado al 60% del lienzo (nominal 66%, con
  margen de seguridad, mismo criterio que el pipeline viejo de FLYmovil).
- Icono plano/legacy: escalado al 80% (pedido explicito).
- Corte cubos/texto: se busca automaticamente la fila mas angosta ("cintura")
  donde el cubo inferior se angosta antes de fundirse visualmente con la
  "Y" de FLY+ (~y=757 de 1254), en vez de asumir una coordenada fija.
- "Icon only" (cubos, para notificacion e icon_only sueltos): ademas del
  corte por fila, se recorta todo lo que quede a la izquierda de x=460
  para excluir las 3 barras de velocidad. Los dos componentes se tocan en
  el arte original en un par de filas, asi que quedan 1-2px sueltos de las
  barras en el borde izquierdo de la notificacion; irrelevante a 24dp.

## Badges dev/staging

Pastilla solida (naranja "DEV" / violeta "STG") centrada en la banda
inferior (~78%-90% de alto) del icono, para sobrevivir el recorte circular/
squircle tipico de Android. Se aplica sobre el icono plano y el adaptativo;
no sobre el monochrome (un solo color, la pastilla no se distinguiria).

## iOS

El proyecto Xcode ya tenia build configs separadas por flavor (`Debug-dev`,
`Release-dev`, `Profile-dev`, idem `-staging` y `-prod`) ademas de las
genericas `Debug`/`Release`/`Profile`. `flutter_launcher_icons` en "modo
flavor" crea un `AppIcon-<flavor>.appiconset` por cada config de flavor y
reapunta SOLO las 3 build configs de ese flavor a el (verificado con
`git diff` del `.pbxproj`: cambia exactamente 3 lineas por flavor). Se corrio
primero sin los yaml de flavor (para refrescar el catalogo compartido
`AppIcon` + las genericas Debug/Release/Profile) y despues con ellos (para
crear `AppIcon-dev`/`AppIcon-staging`/`AppIcon-prod`). No se pudo compilar
ni abrir el proyecto en Xcode para verificar (esta maquina es Linux, ver
CLAUDE.md del repo); el cambio del `.pbxproj` es minimo y acotado, pero
queda sin verificar visualmente.

## Notificaciones / FCM

No hay `flutter_local_notifications` ni `firebase_messaging` en
`pubspec.yaml`: no existe ningun sistema de notificaciones hoy. Se dejaron
los `ic_stat_notification.png` listos en todas las densidades y se agrego
el meta-data `com.google.firebase.messaging.default_notification_icon` en
el `AndroidManifest.xml` apuntando a ese drawable, sin efecto hasta que se
agregue esa dependencia.
