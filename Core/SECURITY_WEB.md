# Seguridad Web - AurisTV

## CORS Configuration

### Headers requeridos en el backend API

```
Access-Control-Allow-Origin: https://auristv.net  # o tu dominio productivo
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With
Access-Control-Max-Age: 86400
```

## Seguridad de Tokens en URLs

### Deep Links Firmados

Los tokens en URLs `/watch/:token/:slug` ahora usan:
- **Firma**: HMAC-SHA256
- **Expiración**: 24 horas
- **Formato**: `base64(payload).base64(signature).timestamp`

### Cómo generar tokens firmados

```dart
import 'package:auris_core/auris_core.dart';

final token = SignedTokenManager.createToken(payload: {
  'source': 'AnimeAV1',
  'url': 'https://animeav1.com/...',
  'episode': '1',
  'season': '1',
});
```

## Almacenamiento Local

### Estado actual
- **Tokens de deep link**: Usa XOR con clave estática (legacy)
- **Recomendación**: Migrar a AES-GCM cuando sea posible
- **Interim**: Los tokens firmados usan HMAC que no requiere almacenamiento seguro

### Próximos pasos
1. Usar `flutter_secure_storage` para datos sensibles en mobile
2. Implementar `encrypt` package con AES-GCM para Hive
3. Considerar biometría para acceso a datos sensibles

## HTTPS Obligatorio

### Configuración requerida
- Todos los dominios deben servir HTTPS
- Certificados válidos (no auto-signed)
- HSTS habilitado: `Strict-Transport-Security: max-age=31536000; includeSubDomains`

## Content Security Policy (CSP)

### Headers recomendados

```
Content-Security-Policy: default-src 'self'; 
  script-src 'self' 'unsafe-inline' https://www.gstatic.com; 
  style-src 'self' 'unsafe-inline'; 
  img-src 'self' data: https:; 
  connect-src 'self' https://*.supabase.co; 
  font-src 'self' https://fonts.gstatic.com;
```

## Referers y Headers de Seguridad

### Requeridos para el reproductor

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

## Hardening de Build Web

### Variables de entorno

Para builds de producción:

```bash
# Usar dart-define para claves sensibles
flutter build web \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# O usar un script que lee .env y pasa las variables
```

### NO hacer esto en producción

❌ Hardcodear claves en el código fuente
❌ Usar dominios de desarrollo en producción  
❌ Exponer endpoints de backend sin autenticación

## Monitoreo de Seguridad

### Eventos a monitorear

1. **Tokens expirados**: Mensajes `[SECURITY] Token expirado`
2. **Firmas inválidas**: Mensajes `[SECURITY] Firma inválida`
3. **URL bloqueadas**: Mensajes `[SECURITY] URL bloqueada`
4. **Keys no configuradas**: Mensajes `[SECURITY WARNING] SUPABASE_ANON_KEY not set`

### Cómo ver

```bash
# Ver logs de Flutter en tiempo real
flutter run --verbose 2>&1 | grep -i security
```

## Checklist de Seguridad Antes de Producir

- [ ] `SUPABASE_ANON_KEY` configurado como variable de entorno
- [ ] Todos los dominios sirviendo HTTPS
- [ ] CORS configurado correctamente en el backend
- [ ] `SignedTokenManager` usando una clave secreta distinta
- [ ] `isSupabaseConfigured` devuelve true
- [ ] No hay warnings de seguridad en logs
- [ ] CSP configurado en el servidor web

---

## Referencias

- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Supabase Security Guide](https://supabase.com/docs/guides/auth/security)