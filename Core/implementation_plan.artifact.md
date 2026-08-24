# Estandarizar tamaño de tarjetas normales con las editoriales

El objetivo es que las tarjetas normales (`FocusablePosterCard`) tengan el mismo tamaño de imagen que las tarjetas editoriales (`EditorialCard`), manteniendo una relación de aspecto de 2:3 para el área del póster.

## Cambios Propuestos

### [Shared Widgets]

#### [MODIFY] [focusable_poster_card.dart](file:///E:/AurisTV/lib/shared/widgets/focusable_poster_card.dart)
- Ajustar bordes y sombras para que sean consistentes con el nuevo tamaño.

### [Home Feature]

#### [MODIFY] [content_row.dart](file:///E:/AurisTV/lib/features/home/widgets/content_row.dart)
- Actualizar el ancho de la tarjeta:
    - Escritorio: 190 -> 200
    - Móvil: 110 -> 140
- Actualizar la altura del contenedor del carrusel:
    - Escritorio: 390 -> 400
    - Móvil: 220 -> 280
- Ajustar la altura de las flechas de navegación para que coincidan con el área de la imagen (300px).

### [Schedule Feature]

#### [MODIFY] [schedule_screen.dart](file:///E:/AurisTV/lib/features/schedule/presentation/schedule_screen.dart)
- Hacer que el tamaño de las tarjetas sea responsivo (actualmente es fijo 190).
- Usar los nuevos tamaños: 200 (Escritorio) y 140 (Móvil).
- Ajustar la altura del carrusel y las flechas.

### [Search Feature]

#### [MODIFY] [search_screen.dart](file:///E:/AurisTV/lib/features/search/presentation/search_screen.dart)
- Ajustar el `childAspectRatio` del `GridView` para mantener la proporción 2:3 en la imagen considerando el área de texto inferior.
- Nuevo `childAspectRatio`: 0.52 -> 0.54 (aprox).

### [Content Detail Feature]

#### [MODIFY] [content_screen.dart](file:///E:/AurisTV/lib/features/content/presentation/content_screen.dart)
- Ajustar el `childAspectRatio` en las secciones de "Relacionados" y "Recomendaciones".

## Plan de Verificación

### Verificación Manual
- Abrir la aplicación en modo Escritorio y comparar visualmente una fila normal con una editorial.
- Abrir la aplicación en modo Móvil y verificar que las tarjetas no se corten y mantengan la proporción.
- Verificar que el foco en TV/Desktop siga funcionando correctamente con el nuevo tamaño.
