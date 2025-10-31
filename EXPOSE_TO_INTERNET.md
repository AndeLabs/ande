# 🌐 Exponer ANDE Chain a Internet

## Tu IP Pública
```
IP: 189.28.81.202
```

## Opción 1: Port Forwarding (Recomendado - Router)

### Paso 1: Configurar Router
1. Accede a tu router (generalmente 192.168.1.1)
2. Ve a **Port Forwarding** / **Reenvío de Puertos**
3. Configura estos puertos:

```
Protocolo | Puerto Externo | IP Local    | Puerto Local | Descripción
----------|----------------|-------------|--------------|------------------
TCP       | 80             | 172.22.176.5| 80           | HTTP/Nginx
TCP       | 443            | 172.22.176.5| 443          | HTTPS/Nginx
TCP       | 8545           | 172.22.176.5| 8545         | RPC HTTP
TCP       | 8546           | 172.22.176.5| 8546         | RPC WebSocket
TCP       | 3000           | 172.22.176.5| 3000         | Grafana
TCP       | 9090           | 172.22.176.5| 9090         | Prometheus
TCP       | 3100           | 172.22.176.5| 3100         | Loki
```

### Paso 2: Verificar Conectividad
```bash
# Desde otro dispositivo o máquina
curl http://189.28.81.202:8545 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

---

## Opción 2: Tunnel (ngrok/Cloudflare) - Para Testing Rápido

### Usando Cloudflare Tunnel (Gratis)

#### Instalar cloudflared
```bash
# Ubuntu/WSL
curl -L --output cloudflared.linux-amd64.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.linux-amd64.deb

# macOS
brew install cloudflare/cloudflare/cloudflared
```

#### Crear Tunnel para RPC
```bash
# Iniciar Cloudflare Tunnel
cloudflared tunnel create ande-rpc

# Configurar routing
cloudflared tunnel route dns ande-rpc rpc.andelabs.io

# Iniciar tunnel
cloudflared tunnel run --url http://localhost:8545 ande-rpc
```

**Resultado:** Tu RPC estará disponible en `https://rpc.andelabs.io`

### Usando ngrok (Gratis con limitaciones)

```bash
# Instalar
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
unzip ngrok-v3-stable-linux-amd64.zip
sudo mv ngrok /usr/local/bin

# Iniciar
ngrok http 8545
```

---

## Opción 3: VPS + Reverse Proxy (Producción)

Si quieres que esté 100% disponible a nivel global:

### Paso 1: Alquilar VPS
- **Proveedores:** DigitalOcean, Vultr, Linode, AWS, GCP
- **Requisitos:** 1GB RAM, 1 vCPU, IP pública estática
- **Costo:** ~$5-10 USD/mes

### Paso 2: Configurar en VPS
```bash
# En tu VPS
apt-get update && apt-get install -y nginx certbot python3-certbot-nginx

# Configurar Nginx como reverse proxy
cat > /etc/nginx/sites-available/ande << 'EOF'
server {
    listen 80;
    server_name rpc.andelabs.io grafana.andelabs.io prometheus.andelabs.io;

    # RPC
    location /rpc {
        proxy_pass http://189.28.81.202:8545;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Grafana
    location /grafana {
        proxy_pass http://189.28.81.202:3000;
        proxy_set_header Host $host;
    }

    # Prometheus
    location /prometheus {
        proxy_pass http://189.28.81.202:9090;
        proxy_set_header Host $host;
    }
}
EOF

# Habilitar
ln -s /etc/nginx/sites-available/ande /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# SSL (Let's Encrypt)
certbot --nginx -d rpc.andelabs.io -d grafana.andelabs.io -d prometheus.andelabs.io
```

### Paso 3: Actualizar DNS
Apunta tus dominios a la IP del VPS en tu proveedor DNS:
```
rpc.andelabs.io          A 1.2.3.4       (IP del VPS)
grafana.andelabs.io      A 1.2.3.4
prometheus.andelabs.io   A 1.2.3.4
```

---

## Opción 4: Docker + Cloudflare (Recomendado para Testnet)

### Configurar Variables en chain.config.ts

```typescript
const RPC_PUBLIC_URL = "https://rpc.andelabs.io";  // Tu dominio
const GRAFANA_URL = "https://grafana.andelabs.io";
const PROMETHEUS_URL = "https://prometheus.andelabs.io";
```

### Actualizar docker-compose.yml

```yaml
services:
  nginx-proxy:
    ports:
      - "0.0.0.0:80:80"   # Escucha en todos los interfaces
      - "0.0.0.0:443:443"
    environment:
      - DOMAIN=andelabs.io
      - PUBLIC_IP=189.28.81.202
```

---

## URLs Disponibles Actualmente

### Local (Dentro de tu red)
```
RPC HTTP:        http://localhost:8545
RPC WebSocket:   ws://localhost:8546
Grafana:         http://localhost:3000 (admin/andechain-admin-2025)
Prometheus:      http://localhost:9090
Loki:            http://localhost:3100
cAdvisor:        http://localhost:8080
```

### Por IP Pública (Requiere Port Forwarding)
```
RPC HTTP:        http://189.28.81.202:8545
RPC WebSocket:   ws://189.28.81.202:8546
Grafana:         http://189.28.81.202:3000
Prometheus:      http://189.28.81.202:9090
```

---

## Verificar que la Red está Accesible

```bash
# Test RPC desde internet
curl -X POST http://189.28.81.202:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Expected response
# {"jsonrpc":"2.0","id":1,"result":"0x..."}

# Ver últimos bloques
curl -s http://189.28.81.202:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq
```

---

## Firewall (Si usas UFW)

```bash
# Permitir puertos RPC
sudo ufw allow 8545/tcp
sudo ufw allow 8546/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 9090/tcp

# Verificar
sudo ufw status
```

---

## Monitoreo de Disponibilidad

```bash
# Monitorear health continuamente
watch -n 5 'curl -s http://189.28.81.202:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}" | jq'
```

---

## Recomendación Final

**Para una testnet pública profesional:**

1. ✅ Usar **Port Forwarding en Router** (corto plazo)
2. ✅ O **Cloudflare Tunnel** (gratuito, sin infraestructura)
3. ✅ O **VPS Reverse Proxy** (producción, máxima control)

**Mi recomendación:** Cloudflare Tunnel (es gratis y muy fácil)

---

**Última actualización:** 2025-10-31
**Status:** Testnet Público Ready ✅
