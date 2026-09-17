# AurisTV — Google TV & Android TV

Este proyecto contiene la aplicación de **AurisTV** optimizada para televisores y dispositivos de streaming.

## Características Principales

- **10ft UI**: Interfaz diseñada para ser vista a 3 metros de distancia, con fuentes y elementos escalados.
- **Navegación D-pad**: Optimizada para ser controlada exclusivamente con el mando a distancia del televisor.
- **Reproducción Nativa**: Integración directa con `media_kit` para el máximo rendimiento en hardware de TV.
- **Sincronización Global**: Comparte historial, favoritos y perfiles con las versiones de Móvil y Web.

## Desarrollo

La aplicación consume el core compartido en `packages/auris_core`. 

Para ejecutar en un emulador o dispositivo real:
```bash
flutter run -d android
```

Asegúrate de que el dispositivo esté en modo "Android TV" para activar las optimizaciones específicas de escalado.

