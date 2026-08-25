# Rediseño de Teclado Virtual (Estilo Netflix)

Este plan detalla los cambios necesarios para transformar el teclado virtual actual en uno con estética similar al de búsqueda de Netflix, mejorando la legibilidad, el contraste y el estado de foco para usuarios de TV.

## User Review Required

> [!IMPORTANT]
> Se cambiará la estructura de bordes compartidos por bloques individuales con espacio entre ellos (gaps), lo que afectará visualmente la densidad del teclado pero mejorará drásticamente la usabilidad en TV.

## Proposed Changes

### [Component] Search Feature

#### [MODIFY] [tv_keyboard.dart](file:///E:/AurisTV_plataformas/TV/lib/features/search/presentation/widgets/tv_keyboard.dart)
*   **Contenedor Principal**:
    *   Cambiar color de fondo a `Colors.white.withOpacity(0.08)`.
    *   Agregar `padding` interno de `20px`.
    *   Eliminar `boxShadow` innecesario si el contraste es suficiente con el fondo nuevo.
*   **Botones Superiores (Acciones)**:
    *   Separarlos de la grilla inferior con un `SizedBox` de `16px`.
    *   Aumentar el espacio entre los dos botones superiores.
    *   Asignarles un fondo más oscuro (`#1a1a1a`) para distinguirlos.
    *   Aumentar el tamaño de los íconos/labels.
*   **Teclas de la Grilla**:
    *   Implementar `GridView` para manejar fácilmente el `spacing` de `8px`.
    *   Cada tecla tendrá fondo `#2a2a2a` y bordes redondeados de `4px`.
    *   Texto en blanco/gris claro, centrado y con tamaño aumentado.
*   **Estado de Foco**:
    *   Fondo: Blanco/Gris muy claro (`#c4c4c4`).
    *   Texto: Negro (`Colors.black`).
    *   Eliminar el degradado actual para un look más "flat" y sólido como en la referencia.

#### [MODIFY] [search_screen.dart](file:///E:/AurisTV_plataformas/TV/lib/features/search/presentation/search_screen.dart)
*   **Lista de Sugerencias**:
    *   Aumentar `SizedBox(height: 32)` a `48` para más separación.
    *   **_TVSuggestionItem**:
        *   Cambiar color de texto no enfocado a un gris más legible (`Colors.white70`).
        *   Aumentar el `padding` vertical o usar `height` para simular `line-height` de `1.8`.

## Verification Plan

### Manual Verification
1.  Abrir la pantalla de búsqueda en el emulador de TV o dispositivo.
2.  Verificar que el teclado tenga el fondo semi-transparente y padding correcto.
3.  Navegar por las teclas con el control remoto/teclado y asegurar que el resaltado sea blanco con texto negro.
4.  Confirmar que las teclas superiores tengan separación clara de la grilla.
5.  Validar que las sugerencias tengan el espaciado y estilo solicitado.
