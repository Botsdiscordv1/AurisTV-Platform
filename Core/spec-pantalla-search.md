# Especificación: Pantalla de búsqueda (Search)

## Objetivo
Reemplazar el estado vacío actual por una pantalla que guíe al usuario incluso antes de escribir, siguiendo el patrón usado por Netflix, Spotify, Disney+ y HBO Max.

---

## 1. Estados de la pantalla

La pantalla tiene 4 estados posibles. El agente debe implementar los 4, no solo el primero.

### Estado A — Pre-búsqueda (input vacío)
Se muestra al entrar a la screen, antes de que el usuario escriba algo.

### Estado B — Escribiendo (typeahead)
Se activa desde el primer carácter. Resultados en vivo, sin esperar "enter".

### Estado C — Con resultados
Se muestra tras una búsqueda con matches.

### Estado D — Sin resultados
Se muestra cuando la búsqueda no tiene matches.

---

## 2. Estado A — Pre-búsqueda (foco de esta spec)

### 2.1 Componentes, en orden

1. **Search bar**
   - Sticky/fija arriba en scroll
   - Placeholder: `"Series, películas, actores, directores..."`
   - Ícono de búsqueda a la izquierda
   - Botón "x" para limpiar (aparece solo con texto)
   - En móvil: teclado se abre automático al entrar a la screen

2. **Búsquedas recientes** (condicional)
   - Solo se muestra si el usuario tiene historial
   - Últimas 5–8 búsquedas, orden más reciente primero
   - Cada ítem: ícono de reloj + texto + botón "x" individual
   - Acción "Borrar todo" al lado del título de sección
   - Si no hay historial: se omite toda la sección (no mostrar mensaje vacío)

3. **Categorías / géneros**
   - Grid de accesos rápidos, cada uno navega directo a resultados filtrados por género
   - Tarjetas con color + ícono + nombre del género
   - Mínimo 6–8 géneros, según catálogo real

4. **Lo más buscado (trending)**
   - Lista numerada (1, 2, 3...) o carrusel
   - Refleja búsquedas populares reales de la plataforma (global o por región)
   - Se recalcula periódicamente en backend, no es contenido estático

### 2.2 Layout responsive

| Breakpoint | Comportamiento |
|---|---|
| Mobile (< 768px) | Todo apilado verticalmente en el orden: recientes → géneros (grid 2 columnas) → trending (lista) |
| Tablet (768–1199px) | Igual que mobile, géneros en grid de 3 columnas |
| Desktop (≥ 1200px) | Layout de 2 columnas: columna izquierda (ancha) = géneros (grid 4 col) + trending (grid 2 col); columna derecha (sidebar, ~320px) = búsquedas recientes |

---

## 3. Estado B — Escribiendo (typeahead)

- Se activa al primer carácter ingresado, sin necesidad de "enter"
- Debounce recomendado: 250–300ms para no saturar backend
- Reemplaza el contenido de pre-búsqueda por resultados en vivo
- Mezclar tipos de resultado: títulos, actores/directores, géneros que matcheen
- Autocompletado: si hay una coincidencia clara, sugerirla arriba de la lista

---

## 4. Estado D — Sin resultados

- Mensaje amigable, no técnico. Ejemplo: `"No encontramos nada para 'xyz'"` (nunca "Error" ni mensajes de sistema)
- Debajo del mensaje, ofrecer alternativas:
  - Sugerencias de búsquedas similares o corregidas
  - Atajo a las categorías (para no dejar la pantalla muerta)
- No dejar la pantalla en blanco

---

## 5. Requisitos de datos / backend

El agente necesita definir o confirmar:

- **Búsquedas recientes**: persistidas por usuario (local o en perfil), no solo en sesión
- **Trending**: endpoint que devuelva top N búsquedas por región/global, actualizado periódicamente (no hardcodeado)
- **Categorías**: lista de géneros disponibles en el catálogo actual, con ícono/color asignado por tipo
- **Typeahead**: endpoint de búsqueda que soporte queries parciales con latencia baja (< 300ms ideal)

---

## 6. Microinteracciones

- Botón "x" limpia el input y vuelve al estado A
- Al borrar una búsqueda reciente individual, actualizar la lista sin recargar toda la pantalla
- "Borrar todo" pide confirmación si el equipo lo considera necesario (opcional, a definir)
- Animación sutil (fade/slide) al pasar entre estados A → B → C/D

---

## 7. Fuera de alcance de esta spec

- Sistema de colores y tipografía definitivos (usar el design system del producto, no los mockups de referencia)
- Copy final de textos (los usados aquí son placeholders)
- Lógica de ranking de resultados de búsqueda
- Accesibilidad detallada (contraste, navegación por teclado, lectores de pantalla) — debe cumplir los estándares del equipo

---

## Referencia visual
Se adjuntaron mockups de referencia (mobile y desktop) para el estado A únicamente, como guía de estructura y jerarquía — no como especificación pixel-perfect.
