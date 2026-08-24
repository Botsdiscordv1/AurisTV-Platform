Quiero hacer una corrección a la implementación de **"Lo más buscado"**.

La dirección general está bien, pero el efecto de los números todavía no representa correctamente el estilo Netflix.

El número debe funcionar como un elemento **gigante detrás del póster**, no como un número simplemente colocado encima o al lado.

La composición debe ser:

```text
[NÚMERO GIGANTE] [PÓSTER]
```

pero con solapamiento:

```text
   1████[PÓSTER]
```

El número debe comenzar bastante hacia la izquierda y el póster debe quedar por encima de él, ocultando parcialmente su parte derecha.

### Corrección visual

* Número extremadamente grande, proporcional al tamaño/alto del póster.
* Solo contorno (`stroke/outline`), sin relleno.
* Gris oscuro/neutro y sutil.
* El número debe sobresalir claramente por la izquierda del póster.
* El póster debe estar en una capa superior al número.
* Debe existir un pequeño solapamiento entre ambos.
* No quiero que el número quede completamente separado del póster.
* No quiero que el número sea pequeño.

Conceptualmente:

```text
        ┌────────────┐
   1    │            │
 ████   │   PÓSTER   │
 ████   │            │
 ████   │            │
        └────────────┘
```

La estructura debería ser un `Stack`:

```text
Stack
 ├── Número gigante / background
 └── Póster / foreground
```

### Responsive

En móvil el número debe reducirse proporcionalmente al tamaño del póster.

No uses un tamaño fijo como `110px` que solo funcione en determinadas pantallas.

El tamaño del número debe calcularse en relación con el tamaño del póster para que la composición conserve el mismo aspecto en:

* Mobile
* Tablet
* Desktop
* TV

### Carrusel

La sección debe permanecer siempre en **una sola fila horizontal**.

Con 5, 6 o más elementos, debe continuar horizontalmente mediante scroll:

```text
1 + póster | 2 + póster | 3 + póster | 4 + póster | 5 + póster | 6 + póster | ...
```

Nunca debe hacer wrap a una segunda línea.

En móvil debe poder deslizarse horizontalmente.

### Importante

Los iconos actuales son únicamente placeholders. La implementación debe estar preparada para que cada elemento utilice posteriormente el **póster real**.

El objetivo final es que visualmente se reconozca inmediatamente como un carrusel **Top 10 estilo Netflix**:

**número gigante de contorno + número parcialmente oculto detrás del póster + fila horizontal scrolleable.**

No agregues elementos decorativos innecesarios; prioriza que esta composición quede correctamente implementada.
