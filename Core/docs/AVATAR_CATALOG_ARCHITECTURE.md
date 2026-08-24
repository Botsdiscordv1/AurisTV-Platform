# Avatar Catalog Architecture

## 1. Objetivo

Implementar en la aplicación un sistema de selección de avatar basado en personajes de anime.

Los avatares serán imágenes locales incluidas dentro de la aplicación Flutter. El servidor solamente se utilizará como herramienta auxiliar para identificar, normalizar y clasificar los personajes utilizando AniList.

Una vez generado el catálogo definitivo, la aplicación debe funcionar completamente de forma local respecto al sistema de avatares.

### Principios principales

- Las imágenes de los avatares pertenecen a la aplicación.
- No descargar imágenes de AniList en tiempo de ejecución.
- No consultar AniList desde Flutter para mostrar avatares.
- El servidor solamente ayuda a construir/verificar el catálogo.
- Los datos definitivos del catálogo deben quedar incluidos dentro de la aplicación.
- Un personaje puede tener múltiples variantes de imagen.
- Las variantes pertenecen al mismo personaje y NO deben tratarse como personajes diferentes.
- Las franquicias tendrán carruseles horizontales independientes.
- No existe un límite fijo de personajes por franquicia.
- Se deben incluir personajes principales, secundarios, antagonistas y otros personajes relevantes.

---

# 2. Arquitectura general

```text
Pinterest / fuentes de imágenes
            │
            ▼
     Imágenes preparadas
            │
            ▼
    Flutter assets/avatars/
            │
            │
            ├─────────────────────────────┐
            │                             │
            ▼                             │
       Nombre archivo                    │
            │                             │
            ▼                             │
      Avatar Builder                     │
            │                             │
            ▼                             │
        Server                           │
            │                             │
            ▼                             │
          AniList                         │
            │                             │
            ▼                             │
  Identificación del personaje            │
  Nombre correcto                         │
  characterId                             │
  clasificación/role                      │
            │                             │
            ▼                             │
     Catálogo definitivo                  │
            │                             │
            └──────────────┬──────────────┘
                           ▼
                   Flutter App
                           │
                           ▼
                 AvatarCatalog local
                           │
                           ▼
                Carruseles por franquicia
```

El servidor NO debe convertirse en un proveedor remoto de imágenes.

Su función es principalmente:

```text
imagen + nombre aproximado
        ↓
identificación mediante AniList
        ↓
datos normalizados
        ↓
catálogo JSON
        ↓
incorporado a Flutter
```

---

# 3. Estructura de assets

Las imágenes deben almacenarse dentro de Flutter.

Propuesta:

```text
assets/
└── avatars/
    ├── dragon_ball/
    │   ├── Goku.webp
    │   ├── Vegeta.webp
    │   ├── Gohan.webp
    │   ├── Gohan_v2.webp
    │   ├── Trunks.webp
    │   └── ...
    │
    ├── one_piece/
    │   ├── Monkey_D_Luffy.webp
    │   ├── Roronoa_Zoro.webp
    │   ├── Sanji.webp
    │   ├── Nami.webp
    │   └── ...
    │
    ├── naruto/
    │   ├── Naruto_Uzumaki.webp
    │   ├── Sasuke_Uchiha.webp
    │   ├── Sakura_Haruno.webp
    │   └── ...
    │
    └── jujutsu_kaisen/
        ├── Gojo_Satoru.webp
        ├── Gojo_Satoru_v2.webp
        ├── Itadori_Yuji.webp
        ├── Fushiguro_Megumi.webp
        └── ...
```

## 3.1 Formato

Preferentemente:

```text
.webp
```

Las imágenes deben estar optimizadas para utilizarse como avatar.

Resolución recomendada:

```text
256x256
```

Se puede utilizar una resolución superior si el diseño actual de la aplicación lo requiere, pero evitar imágenes innecesariamente grandes.

---

# 4. Convención de nombres

Los nombres de archivos deben utilizar caracteres ASCII simples.

Correcto:

```text
Asai_Akari.webp
Asai_Akari_v2.webp
Asai_Akari_v3.webp
```

No utilizar caracteres Unicode estilizados en los nombres físicos de archivos.

Por ejemplo, aunque visualmente pueda utilizarse:

```text
𝐀𝗌𝖺𝗂_𝐀𝗄𝖺𝗋𝗂
```

el archivo debe ser:

```text
Asai_Akari.webp
```

El nombre mostrado al usuario debe almacenarse independientemente:

```json
"name": "Asai Akari"
```

Esto evita problemas con:

- Windows
- Linux
- Flutter
- Git
- rutas de archivos
- comparación de strings
- scripts de generación
- sistemas de build

---

# 5. Personaje vs variante

Este punto es fundamental.

Una variante NO representa un personaje nuevo.

Ejemplo:

```text
Asai_Akari.webp
Asai_Akari_v2.webp
Asai_Akari_v3.webp
```

Representa:

```text
Personaje:
Asai Akari

Variantes:
- Asai_Akari.webp
- Asai_Akari_v2.webp
- Asai_Akari_v3.webp
```

Todas deben compartir el mismo `characterId` de AniList.

---

# 6. Modelo de datos

El catálogo debe separar claramente:

```text
Franquicia
    ↓
Personaje
    ↓
Variantes de imagen
```

Ejemplo:

```json
{
  "franchiseId": "jujutsu-kaisen",
  "name": "Jujutsu Kaisen",
  "avatars": [
    {
      "characterId": 123456,
      "name": "Gojo Satoru",
      "role": "main",
      "variants": [
        "assets/avatars/jujutsu_kaisen/Gojo_Satoru.webp",
        "assets/avatars/jujutsu_kaisen/Gojo_Satoru_v2.webp"
      ]
    },
    {
      "characterId": 123457,
      "name": "Nanami Kento",
      "role": "supporting",
      "variants": [
        "assets/avatars/jujutsu_kaisen/Nanami_Kento.webp"
      ]
    }
  ]
}
```

---

# 7. Identificación del personaje

El servidor debe utilizar AniList para corroborar la identidad del personaje.

El nombre del archivo será solamente una ayuda para realizar el matching.

Ejemplo:

```text
Nanami_Kento_v2.webp
```

El sistema debe:

```text
1. Detectar nombre base.
2. Eliminar sufijo de variante.
3. Convertir "_" en espacios.
4. Normalizar el nombre.
5. Buscar el personaje en AniList.
6. Obtener el characterId.
7. Obtener el nombre oficial/correcto.
8. Obtener información relevante.
9. Determinar la clasificación.
10. Generar el registro definitivo.
```

Resultado:

```text
Archivo:
Nanami_Kento_v2.webp

Nombre normalizado:
Nanami Kento

AniList:
Kento Nanami

characterId:
XXXXXX

role:
supporting
```

---

# 8. Normalización

El sistema de matching debe ser tolerante a pequeñas diferencias.

Ejemplos:

```text
Gojo_Satoru
Gojo Satoru
gojo-satoru
GOJO_SATORU
```

deben poder resolverse hacia el mismo personaje cuando corresponda.

También debe poder eliminar automáticamente sufijos de variantes:

```text
_v2
_v3
_v4
_v5
```

Ejemplo:

```text
Asai_Akari_v3.webp
```

debe producir:

```text
Asai Akari
```

antes de buscar en AniList.

NO se debe eliminar información que forme realmente parte del nombre del personaje.

---

# 9. Nombre definitivo

El catálogo debe conservar el nombre correcto del personaje obtenido/verificado mediante AniList.

No depender únicamente del nombre del archivo.

Ejemplo:

```json
{
  "name": "Kento Nanami",
  "variants": [
    "assets/avatars/jujutsu_kaisen/Nanami_Kento.webp"
  ]
}
```

El archivo puede utilizar un orden diferente por comodidad, pero el nombre mostrado debe ser el correcto.

---

# 10. Clasificación de personajes

Cada personaje debe tener una clasificación.

Valores iniciales:

```text
main
supporting
antagonist
```

La clasificación se utiliza principalmente para organizar el catálogo y determinar el orden.

No es necesario mostrar estas categorías al usuario.

## Orden recomendado

Dentro de cada franquicia:

```text
1. main
2. supporting
3. antagonist
```

Sin embargo, dentro de cada grupo se debe priorizar la relevancia/popularidad del personaje.

Ejemplo:

```text
Jujutsu Kaisen

Gojo
Yuji
Megumi
Nobara
Yuta

Maki
Toge
Panda
Nanami
Todo
Mei Mei
Utahime
...

Sukuna
Geto
Mahito
Jogo
Hanami
...
```

No se debe asumir que un personaje secundario es menos importante para el usuario.

El objetivo es ofrecer una selección amplia.

---

# 11. No limitar la cantidad de personajes

No establecer un límite de 25 personajes por franquicia.

La cantidad debe depender del elenco relevante de cada franquicia.

Ejemplos:

```text
Franquicia pequeña:
15 personajes

Franquicia mediana:
30 personajes

Franquicia grande:
50+ personajes
```

No eliminar personajes relevantes únicamente para mantener un número uniforme.

El objetivo es incluir:

- protagonistas
- secundarios
- antagonistas
- personajes recurrentes
- personajes populares
- personajes de culto
- personajes relevantes para los fans

Evitar únicamente personajes irrelevantes/extras que no tengan suficiente presencia.

---

# 12. Variantes

Un personaje puede tener múltiples imágenes.

Ejemplo:

```text
Gojo_Satoru.webp
Gojo_Satoru_v2.webp
Gojo_Satoru_v3.webp
```

Datos:

```json
{
  "characterId": 123,
  "name": "Gojo Satoru",
  "variants": [
    "Gojo_Satoru.webp",
    "Gojo_Satoru_v2.webp",
    "Gojo_Satoru_v3.webp"
  ]
}
```

Todas pertenecen al mismo personaje.

## Variante por defecto

La primera imagen debe considerarse la variante principal:

```text
Gojo_Satoru.webp
```

Las demás:

```text
Gojo_Satoru_v2.webp
Gojo_Satoru_v3.webp
```

son alternativas.

---

# 13. Diferenciar variantes reales

No todas las diferencias deben convertirse automáticamente en personajes diferentes.

Ejemplo:

```text
Gojo_Satoru.webp
Gojo_Satoru_v2.webp
```

Mismo personaje.

Pero si se quiere diferenciar una versión narrativa concreta:

```text
Gojo_Satoru.webp
Gojo_Satoru_Young.webp
```

continúa perteneciendo al mismo `characterId`, pero puede tener metadata adicional si en el futuro se necesita:

```json
{
  "variantId": "young",
  "label": "Young Gojo"
}
```

No crear otro personaje AniList para una simple variante visual.

---

# 14. Estructura de Flutter

Crear un sistema de catálogo local.

Conceptualmente:

```text
lib/
└── features/
    └── avatar/
        ├── data/
        │   ├── avatar_catalog.dart
        │   └── avatar_catalog.json
        │
        ├── domain/
        │   ├── avatar_character.dart
        │   ├── avatar_franchise.dart
        │   └── avatar_variant.dart
        │
        └── presentation/
            ├── avatar_selector.dart
            ├── avatar_franchise_row.dart
            └── avatar_item.dart
```

La estructura exacta puede adaptarse a la arquitectura existente del proyecto.

No romper la arquitectura actual.

---

# 15. Modelo Flutter

Conceptualmente:

```dart
class AvatarFranchise {
  final String id;
  final String name;
  final List<AvatarCharacter> characters;
}

class AvatarCharacter {
  final int characterId;
  final String name;
  final AvatarRole role;
  final List<String> variants;
}
```

Y:

```dart
enum AvatarRole {
  main,
  supporting,
  antagonist,
}
```

No es obligatorio utilizar exactamente estas clases si el proyecto ya tiene un sistema de modelos equivalente.

---

# 16. Selector de avatar

La interfaz debe seguir un patrón similar a Prime Video/Netflix.

No crear una única cuadrícula gigante.

Debe utilizarse:

```text
Título de franquicia

← avatar → avatar → avatar → avatar → avatar → ...
```

Después:

```text
Siguiente franquicia

← avatar → avatar → avatar → avatar → avatar → ...
```

Ejemplo:

```text
DRAGON BALL

[ Goku ] [ Vegeta ] [ Gohan ] [ Piccolo ] [ Trunks ] [ Bulma ] →


ONE PIECE

[ Luffy ] [ Zoro ] [ Sanji ] [ Nami ] [ Robin ] [ Ace ] →


NARUTO

[ Naruto ] [ Sasuke ] [ Sakura ] [ Kakashi ] [ Itachi ] →


JUJUTSU KAISEN

[ Gojo ] [ Yuji ] [ Megumi ] [ Nobara ] [ Yuta ] [ Maki ] →
```

Cada fila debe ser horizontalmente desplazable de forma independiente.

---

# 17. Diseño de los avatares

Los avatares deben mostrarse como imágenes circulares o con el estilo visual que ya utilice la aplicación.

El sistema debe permitir indicar claramente cuál está seleccionado.

Ejemplo conceptual:

```text
     ○        ○        ◉        ○        ○
   Goku    Vegeta    Gojo      Yuji     Luffy
                       ↑
                    seleccionado
```

El estado seleccionado debe utilizar el sistema visual de selección existente de la aplicación.

No introducir colores arbitrarios que contradigan el diseño actual.

---

# 18. Persistencia del avatar seleccionado

El usuario solamente necesita guardar una referencia al personaje/variante seleccionada.

No guardar la imagen.

Ejemplo:

```json
{
  "avatarCharacterId": 123456,
  "avatarVariant": 1
}
```

O, si resulta más conveniente:

```json
{
  "avatarId": "jujutsu-kaisen:gojo-satoru:v2"
}
```

La aplicación resolverá esa referencia contra el catálogo local.

---

# 19. No guardar URLs remotas

El sistema de avatares no debe depender de:

```text
https://...
```

para las imágenes.

Debe utilizar assets locales:

```text
assets/avatars/...
```

Esto garantiza:

- funcionamiento offline
- carga instantánea
- independencia de AniList
- independencia del servidor
- ausencia de problemas de CDN
- ausencia de peticiones adicionales

---

# 20. Server

El servidor debe incorporar una herramienta/proceso que permita preparar el catálogo.

No es necesario que esta funcionalidad sea una API pública utilizada por la aplicación.

Su propósito es facilitar la construcción del catálogo.

Flujo:

```text
Detectar archivos
        ↓
Extraer nombre
        ↓
Normalizar
        ↓
Buscar en AniList
        ↓
Confirmar personaje
        ↓
Obtener characterId
        ↓
Obtener nombre correcto
        ↓
Asignar role
        ↓
Agrupar variantes
        ↓
Agrupar por franquicia
        ↓
Generar catálogo
```

---

# 21. Agrupación de variantes

El servidor debe detectar:

```text
Asai_Akari.webp
Asai_Akari_v2.webp
Asai_Akari_v3.webp
```

y producir un único personaje:

```text
Asai Akari
    ├── variant 0
    ├── variant 1
    └── variant 2
```

No generar:

```text
Asai Akari
Asai Akari v2
Asai Akari v3
```

como tres personajes independientes.

---

# 22. Agrupación por franquicia

Cada personaje debe pertenecer a una franquicia/sección.

Ejemplo:

```json
{
  "id": "dragon-ball",
  "name": "Dragon Ball",
  "characters": [...]
}
```

La franquicia debe tener un ID estable.

Ejemplos:

```text
dragon-ball
one-piece
naruto
jujutsu-kaisen
demon-slayer
attack-on-titan
bleach
```

No depender del nombre mostrado para identificarla internamente.

---

# 23. Catálogo definitivo

El resultado final debe ser un archivo local incluido dentro de Flutter.

Por ejemplo:

```text
assets/
└── data/
    └── avatar_catalog.json
```

Contenido conceptual:

```json
{
  "version": 1,
  "franchises": [
    {
      "id": "dragon-ball",
      "name": "Dragon Ball",
      "characters": [
        {
          "characterId": 1,
          "name": "Goku",
          "role": "main",
          "variants": [
            "assets/avatars/dragon_ball/Goku.webp",
            "assets/avatars/dragon_ball/Goku_v2.webp"
          ]
        }
      ]
    }
  ]
}
```

La aplicación debe cargar este catálogo localmente.

---

# 24. El servidor no debe ser dependencia de runtime

Una vez generado el catálogo:

```text
Flutter
   │
   ├── avatar_catalog.json
   └── assets/avatars/
```

es suficiente para que todo el sistema funcione.

No debe existir:

```text
Flutter → Server → AniList
```

cada vez que el usuario abre el selector.

El flujo normal debe ser:

```text
Flutter
   ↓
AvatarCatalog local
   ↓
Assets locales
```

---

# 25. Actualizaciones futuras

Si posteriormente se agregan personajes o franquicias, simplemente se actualiza el catálogo de la aplicación.

Ejemplo:

```text
v1.0
Dragon Ball
Naruto
One Piece
...

v1.1
+ Frieren
+ Solo Leveling
+ nuevos personajes
```

No se debe requerir una conexión al servidor para que los avatares existentes funcionen.

---

# 26. Validaciones

El proceso de construcción debe detectar:

### Archivo sin personaje encontrado

```text
WARNING:
assets/avatars/example/Unknown_Character.webp

No matching AniList character found.
```

No agregar automáticamente un personaje sin confirmación.

### Personaje ambiguo

Si AniList devuelve varios candidatos:

```text
WARNING:
Possible matches:
1. Character A
2. Character B
3. Character C
```

Debe permitir seleccionar/confirmar el correcto.

### Variante sin personaje base

```text
Asai_Akari_v3.webp
```

debe poder resolverse como:

```text
Asai Akari
```

aunque no exista una imagen:

```text
Asai_Akari.webp
```

No asumir que la variante principal siempre tiene que existir.

---

# 27. Requisitos importantes

El agente debe revisar el código existente de Flutter y del servidor antes de implementar.

No reemplazar sistemas existentes innecesariamente.

La implementación debe integrarse con:

- arquitectura actual
- almacenamiento actual de preferencias
- sistema actual de assets
- navegación actual
- estado actual de usuario
- sistema de temas actual

Si ya existe un modelo de usuario/perfil, el avatar seleccionado debe integrarse allí en lugar de crear un sistema de persistencia paralelo innecesario.

---

# 28. Resultado esperado

El resultado final debe permitir:

1. Tener cientos de imágenes de personajes distribuidas por franquicia.
2. Mostrar una fila/carrusel independiente por franquicia.
3. Desplazar horizontalmente cada franquicia.
4. Incluir personajes principales y secundarios.
5. Incluir antagonistas y personajes relevantes.
6. No limitar artificialmente el número de personajes.
7. Tener múltiples imágenes para un mismo personaje.
8. Mantener las variantes agrupadas bajo el mismo personaje.
9. Mostrar el nombre correcto del personaje.
10. Mantener todas las imágenes localmente dentro de la app.
11. No depender de AniList durante el uso normal.
12. Utilizar AniList únicamente como herramienta de verificación/preparación de metadata.
13. Persistir localmente el avatar elegido.
14. Permitir agregar nuevas franquicias/personajes mediante una actualización del catálogo.

---

# 29. Resumen de la arquitectura final

```text
                PREPARACIÓN
────────────────────────────────────────

Imágenes
(Pinterest / fuentes seleccionadas)
             │
             ▼
       assets/avatars
             │
             ▼
       Avatar Builder
             │
             ▼
          Server
             │
             ▼
          AniList
             │
             ▼
     Metadata correcta
             │
             ▼
      avatar_catalog.json


                RUNTIME
────────────────────────────────────────

             Flutter
                │
        ┌───────┴────────┐
        ▼                ▼
avatar_catalog.json   assets/avatars
        │                │
        └───────┬────────┘
                ▼
       Avatar Selector
                │
        ┌───────┴──────────────┐
        ▼                      ▼
   Franquicia 1           Franquicia 2
   ───────────             ───────────
   ○ ○ ○ ○ ○ →             ○ ○ ○ ○ ○ →
        │                      │
        └──────────┬───────────┘
                   ▼
            Avatar seleccionado
                   │
                   ▼
             Guardado local
```

## Regla fundamental

**Las imágenes viven en la app.  
Los datos viven en la app.  
AniList solamente ayuda a construir/verificar esos datos.  
El servidor no es necesario para utilizar el sistema de avatares.**