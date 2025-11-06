# 🌐 CONFIGURACIÓN CLOUDFLARE TUNNEL

## 📋 Información del Tunnel

| Propiedad | Valor |
|-----------|-------|
| **Tunnel ID** | `5fced6cf-92eb-4167-abd3-d0b9397613cc` |
| **Tunnel Name** | `ande-blockchain` |
| **Domain** | `ande.network` |
| **Protocol** | QUIC |
| **Status** | ✅ ACTIVO |
| **Datacenters** | 4 (gru02, gru13, gru19, gru20) |
| **Origin IP** | `189.28.81.202` |

---

## 🔧 CONFIGURACIÓN ARCHIVOS

### `/etc/cloudflared/config.yml`

```yaml
tunnel: 5fced6cf-92eb-4167-abd3-d0b9397613cc
credentials-file: /home/sator/.cloudflared/5fced6cf-92eb-4167-abd3-d0b9397613cc.json
origincert: /home/sator/.cloudflared/cert.pem

protocol: quic
grace-period: 30s
metrics: 0.0.0.0:2000
loglevel: info

ingress:
  # RPC Node
  - hostname: rpc.ande.network
    service: http://localhost:8545
    originRequest:
      connectTimeout: 30s
      
  # API
  - hostname: api.ande.network
    service: http://localhost:4000
    originRequest:
      connectTimeout: 30s
      
  # Explorer (BlockScout)
  - hostname: explorer.ande.network
    service: http://localhost:4001
    originRequest:
      connectTimeout: 30s
      
  # Grafana
  - hostname: grafana.ande.network
    service: http://localhost:3000
    originRequest:
      connectTimeout: 30s
      
  # Stats Dashboard
  - hostname: stats.ande.network
    service: http://localhost:8080
    originRequest:
      connectTimeout: 30s
      
  # Visualizer
  - hostname: visualizer.ande.network
    service: http://localhost:8081
    originRequest:
      connectTimeout: 30s
      
  # Signature Collector
  - hostname: signatures.ande.network
    service: http://localhost:8082
    originRequest:
      connectTimeout: 30s
      
  # Frontend principal
  - hostname: ande.network
    service: http://localhost:80
    originRequest:
      connectTimeout: 30s
      
  # WWW
  - hostname: www.ande.network
    service: http://localhost:80
    originRequest:
      connectTimeout: 30s
  
  # Catch-all
  - service: http_status:404
```

### Ubicación de Archivos

```
/etc/cloudflared/config.yml                           ← Configuración del tunnel
/home/sator/.cloudflared/cert.pem                     ← Certificado Cloudflare
/home/sator/.cloudflared/5fced6cf-92eb-4167-abd3-d0b9397613cc.json ← Credentials
/etc/ssl/certs/ande-network.crt                       ← Certificado Origin
/etc/ssl/private/ande-network.key                     ← Private Key Origin
/etc/systemd/system/cloudflared.service               ← Servicio systemd
```

---

## 🔑 CREDENCIALES Y CERTIFICADOS

### Certificado Origin (Cloudflare)

**Válido hasta**: 2040-11-02

```
Hostname(s): *.ande.network, ande.network
Key Format: RSA
Validity: 15 years
```

**Ubicación**: `/etc/ssl/certs/ande-network.crt`

### Credenciales del Tunnel

**Archivo**: `/home/sator/.cloudflared/5fced6cf-92eb-4167-abd3-d0b9397613cc.json`

Contiene:
- Tunnel ID
- Credenciales de autenticación
- Configuración de origen

---

## 📊 DNS RECORDS

### Registros CNAME Creados

```
rpc.ande.network         → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
api.ande.network         → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
explorer.ande.network    → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
grafana.ande.network     → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
stats.ande.network       → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
visualizer.ande.network  → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
signatures.ande.network  → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
www.ande.network         → 5fced6cf-92eb-4167-abd3-d0b9397613cc.cfargotunnel.com
ande.network (apex)      → 76.76.21.0 (A record existente)
```

### Zona ID

```
Zone ID: 1a2374bfe74f97f24191ac70be588f13
Domain: ande.network
```

---

## 🚀 COMANDOS ÚTILES

### Monitoreo

```bash
# Ver estado del tunnel
cloudflared tunnel info ande-blockchain

# Ver logs en tiempo real
sudo journalctl -u cloudflared -f

# Ver últimas 50 líneas de logs
sudo journalctl -u cloudflared -n 50

# Ver métricas Prometheus
curl http://localhost:2000/metrics

# Filtrar métricas específicas
curl http://localhost:2000/metrics | grep cloudflared_tunnel
```

### Control del Servicio

```bash
# Iniciar
sudo systemctl start cloudflared

# Detener
sudo systemctl stop cloudflared

# Reiniciar
sudo systemctl restart cloudflared

# Ver estado
sudo systemctl status cloudflared

# Habilitar en startup
sudo systemctl enable cloudflared

# Deshabilitar en startup
sudo systemctl disable cloudflared
```

### Verificar Conectividad

```bash
# Test RPC
curl -X POST https://rpc.ande.network \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Test DNS
nslookup rpc.ande.network 8.8.8.8

# Test con dig
dig rpc.ande.network +short

# Test de latencia
curl -w "Total time: %{time_total}\n" https://rpc.ande.network
```

---

## 🔐 SEGURIDAD

### Rate Limiting (Cloudflare WAF)

**Crear Regla en Cloudflare Dashboard:**

1. Security → WAF → Rate Limiting Rules
2. Create Rule
   - **Name**: RPC Rate Limit
   - **Match**: `(http.request.uri contains "/v1/rpc")`
   - **Rate**: 100 requests per 10 seconds
   - **Action**: Block

### Bot Management

**Status**: Habilitado automáticamente (Free Plan)

- Bloquea bots maliciosos
- Score < 30: Bloqueado
- Score 30-50: Challenge

### DDoS Protection

**Status**: Automático

- Detecta y mitiga ataques DDoS
- Protección global
- Zero configuración necesaria

### SSL/TLS

**Mode**: Flexible (HTTP origin → HTTPS frontend)

- Cloudflare manejajeden SSL con usuarios
- Comunic interna: HTTP sin encripción
- Recomendado para este setup

---

## 📈 MONITOREO Y ALERTAS

### Métricas Disponibles

```
cloudflared_tunnel_bytes_sent
cloudflared_tunnel_bytes_received
cloudflared_tunnel_connections
cloudflared_tunnel_connection_errors
cloudflared_tunnel_latency
```

### Alertas Recomendadas

En Cloudflare Dashboard → Notifications:

1. **Tunnel Down**
   - Enviar cuando: Tunnel se desconecta
   - Notificar a: Tu email

2. **High Error Rate**
   - Umbral: 5xx errors > 10%
   - Notificar a: Tu email

3. **DDoS Attack Detected**
   - Notificar automáticamente
   - Notificar a: Tu email

### Grafana (Monitoreo Local)

**URL**: `https://grafana.ande.network`

Dashboards:
- Tunnel Status
- RPC Performance
- Network Health

---

## 🔄 BACKUP Y RECUPERACIÓN

### Backup de Configuración

```bash
# Crear backup
mkdir -p ~/backup/cloudflare
cp /etc/cloudflared/config.yml ~/backup/cloudflare/
cp /home/sator/.cloudflared/* ~/backup/cloudflare/
cp /etc/ssl/certs/ande-network.crt ~/backup/cloudflare/
cp /etc/ssl/private/ande-network.key ~/backup/cloudflare/

# Comprimir
tar -czf ~/backup/cloudflare-backup-$(date +%Y%m%d).tar.gz ~/backup/cloudflare/
```

### Restauración

```bash
# Extractar backup
tar -xzf ~/backup/cloudflare-backup-YYYYMMDD.tar.gz

# Restaurar archivos
sudo cp cloudflare/config.yml /etc/cloudflared/
sudo cp cloudflare/ande-network.crt /etc/ssl/certs/
sudo cp cloudflare/ande-network.key /etc/ssl/private/

# Reiniciar servicio
sudo systemctl restart cloudflared
```

---

## 🆘 TROUBLESHOOTING

### Tunnel No Conecta

```bash
# Verificar status
cloudflared tunnel list

# Ver logs detallados
sudo journalctl -u cloudflared -n 100

# Reintentar conexión
sudo systemctl restart cloudflared

# Verificar firewall
sudo iptables -L -n | grep cloudflared
```

### DNS No Resuelve

```bash
# Test con Google DNS
nslookup rpc.ande.network 8.8.8.8

# Flush DNS cache (Linux)
sudo systemd-resolve --flush-caches

# Check Cloudflare DNS
dig rpc.ande.network +trace
```

### Errores de Certificado

```bash
# Verificar certificado
openssl x509 -in /etc/ssl/certs/ande-network.crt -text -noout

# Verificar fecha de expiración
openssl x509 -enddate -noout -in /etc/ssl/certs/ande-network.crt

# Verificar private key
openssl rsa -check -in /etc/ssl/private/ande-network.key
```

### RPC Timeout

```bash
# Aumentar timeout en config.yml:
originRequest:
  connectTimeout: 60s

# Reiniciar
sudo systemctl restart cloudflared
```

---

## 📞 SUPPORT

- **Cloudflare Docs**: https://developers.cloudflare.com/cloudflare-one/
- **GitHub Issues**: https://github.com/cloudflare/cloudflared/issues
- **Status Page**: https://www.cloudflarestatus.com/

---

**Última actualización**: 2025-11-06 16:26 UTC
**Versión**: 1.0.0
**Mantenedor**: OpenCode
