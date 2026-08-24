# AurisTV — Esquema de Colores

Paleta oficial propuesta para la interfaz de **AurisTV**, basada en el naranja del logo y orientada a una experiencia multimedia oscura, moderna y limpia.

## 1. Colores de marca

| Nombre | Hex | Uso |
|---|---|---|
| Brand | `#EF7A1E` | Color principal, logo, acciones importantes |
| Brand Light | `#FF963D` | Hover, foco y estados activos |
| Brand Dark | `#C85F0D` | Estados pressed/active más oscuros |

### Regla principal

El naranja debe funcionar como **color de acento e interacción**, no como color predominante de los fondos.

---

## 2. Fondos y superficies

| Nombre | Hex | Uso |
|---|---|---|
| Background | `#0B0B0D` | Fondo general de la aplicación |
| Surface | `#121214` | AppBar, navegación y paneles |
| Surface 2 / Card | `#19191C` | Tarjetas y contenido |
| Surface 3 / Elevated | `#222226` | Menús, diálogos y elementos elevados |
| Border | `#2C2C31` | Bordes y separadores |

---

## 3. Tipografía

| Nombre | Hex | Uso |
|---|---|---|
| Text Primary | `#F5F5F5` | Títulos y contenido principal |
| Text Secondary | `#A5A5AA` | Descripciones y metadatos |
| Text Disabled | `#5F5F64` | Elementos deshabilitados |

---

## 4. Colores de estado

| Estado | Hex | Uso |
|---|---|---|
| Success | `#35C759` | Operaciones exitosas |
| Error | `#FF453A` | Errores y acciones destructivas |
| Warning | `#FFB340` | Advertencias |
| Info | `#4DA3FF` | Información y estados informativos |

Estos colores deben utilizarse principalmente para comunicar estados y no como colores decorativos.

---

## 5. Paleta definitiva

```text
BRAND
#EF7A1E

BRAND LIGHT
#FF963D

BRAND DARK
#C85F0D

BACKGROUND
#0B0B0D

SURFACE
#121214

CARD
#19191C

ELEVATED
#222226

BORDER
#2C2C31

TEXT PRIMARY
#F5F5F5

TEXT SECONDARY
#A5A5AA

TEXT DISABLED
#5F5F64

SUCCESS
#35C759

ERROR
#FF453A

WARNING
#FFB340

INFO
#4DA3FF
```

---

## 6. Jerarquía visual

La interfaz debe mantener aproximadamente esta proporción visual:

- **80%** negros y grises oscuros
- **15%** blancos y grises claros
- **5%** naranja de marca

El naranja representa la identidad de AurisTV y debe destacar especialmente en:

- Logo
- Botones principales
- Elementos seleccionados
- Reproductor
- Barra de progreso
- Sliders
- Indicadores activos
- Estados de foco
- Acciones principales

### Principio

> **Naranja = interacción e identidad de AurisTV.**

---

## 7. Reproductor multimedia

El reproductor debe utilizar una base todavía más oscura para que el contenido visual tenga protagonismo.

| Elemento | Hex |
|---|---|
| Player Background | `#080809` |
| Player | `#0B0B0D` |
| Controls | `#F5F5F5` |
| Secondary Controls | `#A5A5AA` |
| Progress | `#EF7A1E` |
| Progress Track | `#39393D` |
| Active Button | `#EF7A1E` |

El naranja debe utilizarse principalmente en el progreso y en los controles activos.

---

## 8. Navegación

### Estado normal

```text
Icon: #7D7D83
Text: #7D7D83
```

### Estado seleccionado

```text
Icon: #EF7A1E
Text: #EF7A1E
Indicator: #3D1D0A
```

La barra de navegación no debe convertirse en un bloque naranja; únicamente los elementos activos deben utilizar el color de marca.

---

## 9. Cards

### Estado normal

```text
Background: #19191C
Border:     #2C2C31
```

### Hover

```text
Background: #202024
```

### Seleccionada

```text
Background: #25170E
Border:     #EF7A1E
```

---

## 10. Botones

### Primario

```text
Background: #EF7A1E
Text:       #FFFFFF
Hover:      #FF963D
Pressed:    #C85F0D
```

### Secundario

```text
Background: #222226
Text:       #F5F5F5
Border:     #2C2C31
Hover:      #2A2A2E
```

La acción principal debe ser naranja. Los botones secundarios deben permanecer neutros para mantener una jerarquía clara.

---

## 11. Flutter — ColorScheme

```dart
const auristvOrange = Color(0xFFEF7A1E);

final auristvDarkScheme = ColorScheme(
  brightness: Brightness.dark,

  primary: Color(0xFFEF7A1E),
  onPrimary: Color(0xFFFFFFFF),

  primaryContainer: Color(0xFF5A2A08),
  onPrimaryContainer: Color(0xFFFFDBC7),

  secondary: Color(0xFFFF963D),
  onSecondary: Color(0xFF2A1205),

  secondaryContainer: Color(0xFF3D1D0A),
  onSecondaryContainer: Color(0xFFFFDBC7),

  tertiary: Color(0xFF4DA3FF),
  onTertiary: Color(0xFF001A33),

  error: Color(0xFFFF453A),
  onError: Color(0xFFFFFFFF),

  surface: Color(0xFF121214),
  onSurface: Color(0xFFF5F5F5),

  surfaceContainerHighest: Color(0xFF222226),
  onSurfaceVariant: Color(0xFFA5A5AA),

  outline: Color(0xFF2C2C31),
  outlineVariant: Color(0xFF202024),

  inverseSurface: Color(0xFFF5F5F5),
  onInverseSurface: Color(0xFF171719),
  inversePrimary: Color(0xFFC85F0D),
);
```

---

## 12. Flutter — ThemeData base

```dart
final auristvTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: auristvDarkScheme,

  scaffoldBackgroundColor: const Color(0xFF0B0B0D),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF121214),
    foregroundColor: Color(0xFFF5F5F5),
    elevation: 0,
  ),

  cardTheme: const CardThemeData(
    color: Color(0xFF19191C),
    elevation: 0,
    margin: EdgeInsets.zero,
  ),

  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFF121214),
    indicatorColor: Color(0xFF5A2A08),
  ),

  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF19191C),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(
        color: Color(0xFF2C2C31),
      ),
    ),
  ),
);
```

---

## 13. Principios de diseño

1. **Mantener `#EF7A1E` como color de identidad de AurisTV.**
2. Usar fondos oscuros para que el contenido multimedia tenga protagonismo.
3. Reservar el naranja para acciones, selección y progreso.
4. Evitar grandes superficies completamente naranjas.
5. Mantener una jerarquía clara entre acciones primarias y secundarias.
6. Utilizar los colores de estado únicamente cuando corresponda.
7. Mantener consistencia entre pantallas, reproductor y navegación.

### Identidad visual

```text
Fondos      → #0B0B0D / #121214
Superficies → #19191C / #222226
Texto       → #F5F5F5 / #A5A5AA
Marca       → #EF7A1E
Estados     → Verde / Rojo / Amarillo / Azul
```

**Concepto:** una interfaz predominantemente oscura donde el naranja de AurisTV funciona como elemento visual distintivo y guía de interacción.
