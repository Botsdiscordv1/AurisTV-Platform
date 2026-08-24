# AurisTV - Multi-platform Entertainment System

Este repositorio contiene el ecosistema completo de **AurisTV**, organizado bajo una arquitectura de **Monorepo**. Esta estructura separa la lógica de negocio (Core) de las implementaciones visuales para cada dispositivo, permitiendo una máxima reutilización de código.

## 🏗️ Arquitectura del Proyecto

El proyecto está dividido en los siguientes módulos:

*   **`Core/`**: El cerebro del sistema. Contiene los modelos de datos, servicios de API (Supabase, Dio), persistencia local (Hive) y lógica de negocio compartida. Está diseñado como un paquete local independiente.
*   **`Web_Desktop/`**: Implementación optimizada para navegadores web y aplicaciones de escritorio (Windows/macOS/Linux).
*   **`Movil/`**: Aplicación para dispositivos móviles (Android e iOS).
*   **`TV/`**: Versión específica optimizada para Android TV.

## 📁 Estructura de Carpetas

```text
/
├── Core/
│   └── packages/
│       ├── auris_core/            # Lógica central del sistema
│       └── youtube_player_web/    # Overrides específicos para web
├── Web_Desktop/                   # Proyecto Flutter (Web & Win)
├── Movil/                         # Proyecto Flutter (Android & iOS)
├── TV/                            # Proyecto Flutter (Android TV)
└── README.md                      # Esta guía
```

## 🚀 Guía de Desarrollo

### Requisitos
*   Flutter SDK (v3.3.0 o superior)
*   Dart SDK (v3.3.0 o superior)

### Inicialización
Al ser un monorepo, cada módulo debe resolver sus dependencias. Puedes entrar a cada carpeta y ejecutar:

```bash
flutter pub get
```

### Ejecutar la Versión Web
```bash
cd Web_Desktop
flutter run -d chrome
```

## 🌐 Despliegue (Cloudflare Pages)

Este repositorio está configurado para desplegarse automáticamente en **Cloudflare Pages**. 

**Configuración de Build en Cloudflare:**
- **Root directory:** `/`
- **Build command:** `cd Web_Desktop && flutter build web --release --base-href /Web/`
- **Build output directory:** `/Web_Desktop/build/web`

---
© 2026 AurisTV - Multimedia Personal.
