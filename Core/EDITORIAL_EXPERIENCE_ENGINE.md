# EDITORIAL_EXPERIENCE_ENGINE.md

# AurisTV Editorial Experience Engine
### Especificación funcional y arquitectónica

Versión: 1.0

---

# Objetivo

Crear un sistema editorial que diferencie AurisTV de otras aplicaciones de streaming.

La mayoría de plataformas muestran únicamente contenido ordenado por:

- Trending
- Popular
- Score
- Más vistos

AurisTV incorporará un sistema editorial compuesto por:

- Editorial Sections
- Editorial Badges
- Editorial Cards

Este sistema convivirá con el motor de recomendaciones, pero será completamente independiente.

---

# Filosofía

Un usuario no solo busca contenido.

También busca descubrir historias.

AurisTV debe transmitir que detrás de la plataforma existe una selección cuidada de obras que realmente merecen ser vistas.

El objetivo es generar una identidad propia.

---

# Arquitectura

```
                 Home

                  │

      ┌───────────┴────────────┐

      │                        │

Recommendation Engine   Editorial Engine

      │                        │

      ▼                        ▼

 Personalized         Curated Collections

      │                        │

      └───────────┬────────────┘

                  ▼

           Home Section Builder
```

---

# Componentes

## Editorial Engine

Nuevo módulo responsable de construir toda la experiencia editorial.

Responsabilidades:

- generar colecciones
- asignar badges
- definir layouts
- decidir variantes visuales

No debe depender del Recommendation Engine.

---

# Editorial Sections

Representan colecciones completas.

No son recomendaciones.

Son selecciones editoriales.

Ejemplos.

---

## ⭐ Títulos inolvidables

Historias que dejaron una huella en generaciones.

---

## 👑 Obras maestras

Narrativa, dirección y calidad sobresaliente.

---

## 💎 Joyas ocultas

Excelentes animes con poca popularidad.

---

## 🔥 Imprescindibles

Todo fan del anime debería verlos.

---

## 🏆 Ganadores de premios

Premiados por la industria.

---

## 🌸 Clásicos del Anime

Obras que siguen vigentes después de muchos años.

---

## 🎬 Películas imprescindibles

Películas que todo aficionado debería conocer.

---

## 🎭 Para empezar en el Anime

Colección para nuevos usuarios.

---

## 🎥 Del mismo estudio

Ejemplo.

Ufotable

MAPPA

Kyoto Animation

Bones

---

## 🎬 Del mismo director

Makoto Shinkai

Hayao Miyazaki

Satoshi Kon

Mamoru Hosoda

---

## ❤️ Porque te gustó...

Colección híbrida.

Ejemplo.

Porque viste:

Death Note

↓

Monster

Code Geass

Psycho-Pass

---

# Editorial Badges

Los badges representan prestigio.

Son atributos del contenido.

No de la colección.

Un mismo anime puede aparecer en distintas colecciones conservando su badge.

---

## Badge MÍTICO

Representa obras que marcaron una generación.

Extremadamente exclusivo.

Objetivo:

menos del 1% del catálogo.

Ejemplos.

- Death Note
- Attack on Titan
- Fullmetal Alchemist Brotherhood

---

## Badge OBRA MAESTRA

Calidad excepcional.

Puede asignarse mediante algoritmo + aprobación editorial.

---

## Badge JOYA OCULTA

Muy alta calidad.

Popularidad baja o media.

---

## Badge IMPRESCINDIBLE

Recomendado para cualquier usuario.

Especialmente principiantes.

---

## Badge FAVORITO

Muy querido por la comunidad.

Basado principalmente en favoritos.

---

## Badge PREMIADO

Ganadores de premios importantes.

---

## Badge CLÁSICO

Series con gran antigüedad que siguen siendo relevantes.

---

# Reglas

Los badges deben ser muy exclusivos.

No deben perder valor.

No todos los animes pueden tener uno.

---

# Arquitectura

```
Media

↓

EditorialBadgeResolver

↓

EditorialBadge

↓

Card Theme
```

---

# Modelo

```dart
enum EditorialBadge {

  mythical,

  masterpiece,

  hiddenGem,

  essential,

  favorite,

  awardWinner,

  classic

}
```

---

# Editorial Card

No deben existir múltiples widgets.

Debe existir un único componente.

```
EditorialCard
```

El aspecto dependerá únicamente del badge.

Ejemplo.

```dart
EditorialCard(

    media: media,

    badge: EditorialBadge.masterpiece,

)
```

---

# Badge Theme

Cada badge define un tema visual.

```dart
class BadgeTheme {

    Color primary;

    Color secondary;

    CardFrame frame;

    BadgeIcon icon;

    Gradient gradient;

}
```

---

# Temas

## ⭐ MÍTICO

Colores

- Dorado
- Ámbar

Sensación

Legendario

---

## 👑 OBRA MAESTRA

Colores

- Morado
- Violeta

Sensación

Prestigio

---

## 💎 JOYA OCULTA

Colores

- Turquesa
- Cian

Sensación

Descubrimiento

---

## 🔥 IMPRESCINDIBLE

Colores

- Naranja
- Rojo

Sensación

Potencia

---

## ❤️ FAVORITO

Colores

- Rosa
- Magenta

Sensación

Cercanía

---

## 🏆 PREMIADO

Colores

- Azul
- Celeste

Sensación

Reconocimiento

---

## 🌸 CLÁSICO

Colores

- Verde jade
- Esmeralda

Sensación

Atemporal

---

# Card Frames

El badge no solo cambia colores.

También modifica:

- bordes
- esquinas
- degradados
- decoración

Pero siempre utilizando el mismo componente.

No deben existir:

MythicalCard

MasterpieceCard

ClassicCard

etc.

---

# Tipos de Cards

## Standard Card

Card por defecto.

Representa aproximadamente el 90% del catálogo.

---

## Editorial Card

Card utilizada cuando un anime posee un badge editorial.

Representa prestigio.

---

## Hero Card

Card grande utilizada en:

- banners
- destacados
- estrenos

---

## Collection Card

Representa una colección.

No representa un anime.

Ejemplo.

```
⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐

TÍTULOS

INOLVIDABLES

25 obras

⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐
```

Al pulsarla.

Abre una pantalla dedicada.

---

# Collection Screen

Cada colección debe abrir una pantalla propia.

Ejemplo.

```
Título

TÍTULOS INOLVIDABLES

Descripción

Historias que dejaron huella en generaciones.

--------------------------------

Grid

Editorial Cards
```

---

# Home Builder

El Home podrá mezclar.

- recomendaciones
- algoritmos
- colecciones editoriales

Ejemplo.

```
Continuar viendo

↓

Recomendado para ti

↓

⭐ Títulos inolvidables

↓

Trending

↓

💎 Joyas ocultas

↓

Más populares

↓

🏆 Ganadores de premios

↓

Películas imprescindibles
```

---

# Escalabilidad

Agregar una nueva colección no debe requerir modificar Flutter.

Debe bastar con registrar.

```
EditorialCollection
```

y

```
EditorialBadgeTheme
```

---

# Beneficios

- Identidad propia para AurisTV.
- Mayor descubrimiento de contenido.
- Diferenciación frente a otras plataformas.
- Reutilización de componentes.
- Arquitectura desacoplada.
- Escalable.
- Fácil mantenimiento.
- Permite combinar inteligencia artificial, recomendaciones y curación editorial.

---

# Visión

El objetivo no es únicamente reproducir anime.

El objetivo es que AurisTV se sienta como una plataforma con criterio propio, donde las recomendaciones automáticas conviven con una selección editorial cuidadosamente diseñada. Las Editorial Sections ayudan al usuario a descubrir contenido con contexto, mientras que los Editorial Badges destacan obras excepcionales en cualquier parte de la aplicación. Juntos forman un sistema reutilizable, escalable y coherente que aporta una identidad única a AurisTV.