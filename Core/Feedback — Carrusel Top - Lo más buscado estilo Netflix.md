Quiero terminar y corregir la implementación de la sección **"Lo más buscado"** para que siga realmente el patrón visual de Netflix Top 10.

La implementación actual va en la dirección correcta, pero hay que ajustar principalmente la composición de los números y el comportamiento responsive.

### 1. Composición de cada elemento

Cada elemento debe estar compuesto por:

```text
[NÚMERO GIGANTE] [PÓSTER]
```

Pero el número debe quedar **visualmente detrás del póster**, no simplemente encima del póster.

El efecto buscado es:

- El número gigante comienza bastante a la izquierda.
- El póster se coloca encima de la parte derecha del número.
- El póster debe ocultar parcialmente el número.
- El resultado debe parecer una sola pieza visual, como el carrusel Top 10 de Netflix.
- El número debe sobresalir claramente por el lado izquierdo del póster.

Ejemplo conceptual:

```text
       ┌───────────┐
  1    │           │
 ███   │   PÓSTER  │
 ███   │           │
 ███   │           │
       │           │
       └───────────┘
```

La parte derecha del número queda parcialmente cubierta por el póster.

### 2. Número

El número debe utilizar:

- Tipografía extremadamente grande y pesada.
- Solo contorno (`stroke/outline`), sin relleno.
- Color gris oscuro/neutro.
- Opacidad suficiente para que sea visible, pero sin competir con el póster.
- Debe tener un tamaño proporcional al alto del póster.

No usar números pequeños ni números completamente separados del póster.

La prioridad visual debe ser:

**Número grande → Póster → contenido secundario**

### 3. Solapamiento

El número y el póster deben tener un pequeño solapamiento horizontal.

No quiero:

```text
1     [PÓSTER]
```

Quiero:

```text
1████[PÓSTER]
```

donde `████` representa la parte del número que queda detrás del póster.

El póster debe estar en una capa superior al número.

Conceptualmente:

```text
Stack
 ├── Número gigante (background)
 └── Póster (foreground)
```

### 4. Responsive / Mobile

En móvil el número debe reducirse proporcionalmente para no ocupar demasiado espacio.

No usar un tamaño fijo que funcione únicamente para desktop.

El tamaño del número debe calcularse en relación con el tamaño/alto del póster.

La composición debe seguir siendo reconocible como:

**número gigante + póster**

incluso en pantallas pequeñas.

### 5. Carrusel horizontal

La sección debe ser una única fila horizontal.

Debe utilizar scroll horizontal:

```text
1 + poster | 2 + poster | 3 + poster | 4 + poster | 5 + poster | ...
```

Nunca debe hacer wrap:

```text
1 + poster | 2 + poster | 3 + poster
4 + poster | 5 + poster | 6 + poster
```

Si existen más de 5 o 6 elementos, simplemente deben continuar hacia la derecha mediante scroll horizontal.

El usuario debe poder deslizar la fila horizontalmente en móvil.

### 6. Espaciado

Evitar demasiado espacio entre el número y el póster.

El número debe sentirse integrado con el póster.

También evitar que los elementos estén tan juntos que los números de una tarjeta interfieran visualmente con la siguiente.

### 7. Importante

Los iconos actuales son únicamente placeholders.

La estructura debe quedar preparada para que posteriormente cada elemento utilice el **póster real del contenido**.

No diseñar la solución alrededor de los iconos actuales.

### Objetivo visual

Quiero que al ver la sección inmediatamente se perciba como un carrusel tipo **Netflix Top 10**, no como una lista normal de tarjetas numeradas.

La referencia visual principal es:

**número gigante de contorno + número parcialmente oculto detrás del póster + fila horizontal scrolleable.**

Prioriza este efecto sobre cualquier decoración adicional.