# Guía de Configuración: Reverse Proxy HTTPS con Caddy para AurisTV

Este documento detalla los pasos necesarios para configurar el VPS de forma que proporcione una conexión segura (HTTPS) compatible con la aplicación Flutter Web y las aplicaciones nativas.

## 1. Instalación de Caddy (Servidor Web con SSL Automático)
Ejecuta los siguientes comandos para instalar Caddy en Ubuntu/Debian:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

## 2. Configuración del Enrutamiento (Caddyfile)
Caddy gestionará automáticamente los certificados SSL de Let's Encrypt para el dominio de DuckDNS.

1. Abre el archivo de configuración:
   ```bash
   sudo nano /etc/caddy/Caddyfile
   ```

2. Reemplaza el contenido con el siguiente bloque:
   ```caddy
   auristvanime.duckdns.org {
       # Redirige el tráfico HTTPS al puerto local del servidor de Anime
       reverse_proxy localhost:3000

       # Cabeceras optimizadas para Flutter Web (CORS)
       header {
           Access-Control-Allow-Origin *
           Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE"
           Access-Control-Allow-Headers "*"
           Access-Control-Expose-Headers "*"
       }
   }
   ```

## 3. Configuración del Firewall
Asegúrate de que los puertos estándar para tráfico web estén abiertos:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

## 4. Reinicio y Verificación
Aplica la configuración y verifica que no haya errores de certificado:

```bash
# Reiniciar Caddy para solicitar el certificado SSL
sudo systemctl restart caddy

# Verificar que el servicio esté corriendo correctamente
sudo systemctl status caddy

# Monitorizar errores en tiempo real
sudo journalctl -u caddy -f
```

---
**Nota para el Agente:** Una vez completado, la URL `https://auristvanime.duckdns.org` será el nuevo punto de entrada para la API de AurisTV, solucionando los errores de "Mixed Content" en el despliegue de Cloudflare.
