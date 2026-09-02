# Plan de Mejora: Barra de Brillo y Volumen Dinámica (Cápsula Central)

Este plan detalla la migración de los indicadores laterales de brillo y volumen a un componente centralizado tipo "cápsula dinámica" ubicado en la parte superior del reproductor, siguiendo las tendencias de diseño de aplicaciones modernas.

## User Review Required

> [!IMPORTANT]
> Se cambiará la orientación de la barra de progreso de vertical a horizontal para ajustarse al nuevo diseño de cápsula.

> [!NOTE]
> El componente será auto-excluyente: el indicador de brillo y volumen compartirán la misma posición y estilo, apareciendo según la interacción más reciente del usuario.

## Proposed Changes

### Player Screen Component

#### [MODIFY] [player_screen.dart](file:///E:/AurisTV_plataformas/Movil/lib/features/player/presentation/player_screen.dart)

1.  **Rediseño de `_buildGestureIndicator`**:
    *   Cambiar el contenedor principal a una cápsula horizontal (`Row` dentro de un `Container` con `StadiumBorder`).
    *   Ajustar el tamaño de los iconos y fuentes para un look más minimalista.
    *   Implementar una barra de progreso horizontal que refleje el valor actual.
    *   Eliminar el `Align` interno para permitir un posicionamiento flexible desde el método `build`.

2.  **Actualización del método `build`**:
    *   Envolver las llamadas a `_buildGestureIndicator` en un `Positioned` con `top: 20` y `left: 0, right: 0`.
    *   Asegurar que el componente esté centrado horizontalmente usando `Center`.

3.  **Refinamiento de Estilos**:
    *   Usar un fondo oscuro semi-transparente con desenfoque (opcional, dependiendo de lo que permita el rendimiento).
    *   Mantener el feedback visual para el modo "Boost" de volumen (color naranja/rayo).

## Verification Plan

### Manual Verification
1.  **Gesto de Brillo**: Deslizar verticalmente en el lado izquierdo y verificar que aparezca la cápsula en el centro superior con el icono de sol.
2.  **Gesto de Volumen**: Deslizar verticalmente en el lado derecho y verificar que aparezca la cápsula en el mismo lugar con el icono de parlante.
3.  **Alternancia**: Cambiar rápidamente entre brillo y volumen para asegurar que solo una cápsula sea visible a la vez y se actualice correctamente.
4.  **Modo Boost**: Subir el volumen por encima del 100% (si es soportado) y verificar el cambio de color a naranja y el icono de rayo.
