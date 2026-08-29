# Corrección de centrado de Tráiler y Fondo en Pantalla de Detalles

El objetivo es corregir el centrado del video del tráiler y la imagen de fondo en la versión de escritorio de la pantalla de detalles. Actualmente, estos elementos están desplazados hacia la derecha debido a que sus contenedores tienen un ancho del 100% de la pantalla pero comienzan con un offset a la izquierda, lo que desplaza su centro geométrico (y por ende, los controles del reproductor como el icono de pausa) fuera del área visible central.

## Cambios Propuestos

### [Content Feature](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/content/presentation/content_screen.dart)

#### [MODIFY] [content_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/content/presentation/content_screen.dart)

Se ajustarán las propiedades `right` de los widgets `Positioned` que contienen el fondo (Backdrop) y el tráiler para que terminen en el borde derecho de la pantalla (`right: 0`). Al reducir el ancho del contenedor al área visible real (o al menos al área desde su inicio hasta el borde derecho), el `OverflowBox` con `alignment: Alignment.center` centrará correctamente el contenido en el espacio disponible.

1.  **Capa de Imagen (Backdrop)**: Cambiar `right: -width * 0.22` por `right: 0`. Esto hará que el contenedor pase de un ancho `1.0w` a `0.78w`, centrando el fondo en el 78% derecho de la pantalla.
2.  **Capa de Tráiler**: Cambiar `right: -width * 0.35` por `right: 0`. Esto hará que el contenedor pase de un ancho `1.0w` a `0.65w`, centrando el video en el 65% derecho de la pantalla. Esto moverá el icono de pausa (que reside en el centro del video) a la posición `0.35w + (0.65w / 2) = 0.675w`, que es el centro exacto del área visible del tráiler.

## Plan de Verificación

### Verificación Manual
- Abrir la pantalla de detalles en un navegador (Web Desktop).
- Verificar que el tráiler se inicie y que el icono de pausa (al aparecer) esté centrado horizontalmente en el espacio a la derecha de la sinopsis.
- Verificar que el gradiente de fusión siga cubriendo adecuadamente la zona de texto y que no haya saltos visuales en los bordes.
- Comprobar que el fondo (backdrop) se vea equilibrado y no excesivamente desplazado a la derecha.
