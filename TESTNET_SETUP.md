# ANDE Chain Testnet - Production Setup & Operations

## 🚀 Quick Start

### Iniciar la red testnet completa
```bash
cd /mnt/c/Users/sator/andelabs/ande
docker compose up -d
```

### Verificar estado de servicios
```bash
docker compose ps
```

### Ver logs en tiempo real
```bash
docker compose logs -f ev-reth-sequencer
docker compose logs -f evolve-sequencer
docker compose logs -f celestia-light
```

---

## 📋 Servicios Configurados

### 1. **ev-reth-sequencer** (Puerto 8545/8546/8551)
- Ejecución de transacciones EVM
- HTTP RPC en puerto 8545
- WebSocket en puerto 8546
- Engine API en puerto 8551
- **Health Check:** Cada 30s via `eth_blockNumber`
- **Auto-restart:** Habilitado

### 2. **evolve-sequencer** (Puerto 7331/7676)
- Consenso y producción de bloques
- RPC en puerto 7331
- P2P en puerto 7676
- **Health Check:** Cada 30s via `/status`
- **Auto-restart:** Habilitado

### 3. **celestia-light** (Puerto 2121/26658)
- Data Availability Layer (Mocha-4)
- P2P en puerto 2121
- RPC en puerto 26658
- **Health Check:** Cada 30s verificando puerto
- **Auto-restart:** Habilitado

### 4. **prometheus** (Puerto 9090)
- Recolección de métricas
- Retención: 30 días
- **Health Check:** Cada 30s
- **Auto-restart:** Habilitado

### 5. **grafana** (Puerto 3000)
- Dashboard de monitoreo
- Usuario: `admin`
- Contraseña: `andechain-admin-2025`
- **Health Check:** Cada 30s
- **Auto-restart:** Habilitado

### 6. **loki** (Puerto 3100)
- Centralización de logs
- Integración con Grafana
- **Health Check:** Cada 30s
- **Auto-restart:** Habilitado

### 7. **nginx-proxy** (Puerto 80/443)
- Reverse proxy para acceso público
- Rate limiting
- SSL/TLS ready
- **Health Check:** Cada 30s
- **Auto-restart:** Habilitado

### 8. **cadvisor** (Puerto 8080)
- Monitoreo de recursos de contenedores
- Métricas en tiempo real
- **Auto-restart:** Habilitado

---

## 🔍 Health Checks & Monitoreo

### Health Check Automático (cada 5 minutos)
```bash
# Ejecutar manualmente
./scripts/health-check-monitor.sh

# Ver logs
tail -f logs/health-check-$(date +%Y-%m-%d).log

# Ver alertas
tail -f logs/alerts.log
```

### Configurar cron automático
```bash
./scripts/setup-monitoring-cron.sh
```

### Verificar estado actual
```bash
docker compose ps
docker stats
```

---

## 📊 Acceso a Dashboards

### Grafana (Monitoreo Visual)
```
http://localhost:3000
Usuario: admin
Contraseña: andechain-admin-2025
```

**Dashboards Disponibles:**
- ANDE Chain Overview
- EV-Reth Metrics
- Evolve Sequencer Metrics
- System Resources

### Prometheus (Métricas Raw)
```
http://localhost:9090
```

### cAdvisor (Container Metrics)
```
http://localhost:8080
(Requiere autenticación via nginx)
```

---

## 💾 Persistencia & Backups

### Volúmenes Configurados
```
- sequencer-data    → Datos de ev-reth
- evolve-data       → Datos de Evolve
- celestia-data     → Datos de Celestia
- prometheus-data   → Métricas (30 días)
- grafana-data      → Configuración
- loki-data         → Logs
- jwttoken-sequencer → JWT para autenticación
```

### Backup Manual
```bash
# Respaldar volúmenes principales
docker run --rm -v sequencer-data:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/sequencer-backup-$(date +%s).tar.gz -C / data

docker run --rm -v evolve-data:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/evolve-backup-$(date +%s).tar.gz -C / data
```

### Rotación Automática de Logs
```
Configurado en docker-compose.yml:
- max-size: 100m por servicio
- max-file: 10 archivos
```

---

## 🔧 Configuración de Red Pública

### Exponer puertos (Nginx)
```
HTTP:  80   → ev-reth RPC (localhost:8545)
HTTP:  80   → Grafana (localhost:3000)
WS:    80   → ev-reth WebSocket (localhost:8546)
```

### URLs Públicas (reemplazar con tu IP/dominio)
```
RPC HTTP:    http://<YOUR_IP>/rpc
RPC WebSocket: ws://<YOUR_IP>/ws
Evolve RPC:  http://<YOUR_IP>/evolve
Grafana:     http://<YOUR_IP>/grafana
Metrics:     http://<YOUR_IP>/metrics (protegido)
```

### Firewall (UFW)
```bash
# Permitir tráfico HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Permitir puertos internos (si es necesario)
sudo ufw allow 8545  # ev-reth HTTP
sudo ufw allow 8546  # ev-reth WebSocket
sudo ufw allow 7331  # Evolve RPC
```

---

## 🚨 Troubleshooting

### Servicio no inicia
```bash
# Ver logs detallados
docker compose logs <service-name>

# Reiniciar servicio
docker compose restart <service-name>

# Reconstruir imagen (si es necesario)
docker compose up -d --force-recreate <service-name>
```

### Alto uso de recursos
```bash
# Ver uso actual
docker stats

# Limpiar volúmenes antiguos
docker volume prune

# Limpiar imágenes sin usar
docker image prune -a
```

### RPC no responde
```bash
# Verificar ev-reth directamente
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Verificar nginx
curl -v http://localhost/health
```

### Logs muy grandes
```bash
# Limpiar logs específicos
docker system prune -a

# Rotación manual
truncate -s 0 $(docker inspect --format='{{.LogPath}}' <container-id>)
```

---

## 📈 Performance Tuning

### Limitar recursos
```yaml
# En docker-compose.yml agregue en cada servicio:
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
    reservations:
      cpus: '1'
      memory: 2G
```

### Optimizar Prometheus
```bash
# Aumentar retención si hay espacio
# En docker-compose.yml, cambiar:
--storage.tsdb.retention.time=90d
```

### Optimizar Loki
```bash
# Configurar límites de retención
# Editar loki config para ajustar retention_deletes_enabled
```

---

## 🔐 Seguridad

### Cambiar contraseñas
```bash
# Grafana admin
http://localhost:3000/admin/users
# Cambiar contraseña de admin-2025

# HTTP Basic Auth (Nginx)
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

### Rate Limiting (activo)
```
RPC endpoints: 10 req/s por IP (burst 20)
API endpoints: 100 req/s por IP
```

### SSL/TLS (si se configuran certificados)
```bash
# Colocar certificados en:
./certs/

# Configurar nginx para SSL
# Editar ./infra/stacks/single-sequencer/nginx.conf
```

---

## 📝 Comandos Útiles

### Iniciar/Parar toda la red
```bash
# Iniciar
docker compose up -d

# Parar
docker compose down

# Parar y limpiar volúmenes (⚠️ PELIGRO)
docker compose down -v
```

### Ver estado detallado
```bash
# Servicios
docker compose ps

# Estadísticas
docker stats

# Información de redes
docker network inspect andechain-p2p
```

### Ejecutar comandos en contenedores
```bash
# Ejecutar en ev-reth
docker compose exec ev-reth-sequencer /usr/local/bin/ev-reth --version

# Ejecutar en Evolve
docker compose exec evolve-sequencer evm-single status

# Bash interactivo
docker compose exec <service> /bin/bash
```

---

## 🎯 Checklist de Producción

- [ ] Docker compose está corriendo
- [ ] Todos los servicios muestran "Up" en `docker compose ps`
- [ ] Health checks pasan (ver `./logs/health-check-*.log`)
- [ ] Grafana accesible en puerto 3000
- [ ] RPC responde a `eth_blockNumber`
- [ ] Nginx reverse proxy funcionando en puerto 80
- [ ] Cron job de health check configurado (`crontab -l`)
- [ ] Backups automáticos configurados
- [ ] Firewall abierto para puertos necesarios
- [ ] Monitoreo activo en Prometheus
- [ ] Logs centralizados en Loki
- [ ] Alertas en Grafana configuradas

---

## 📞 Soporte

- **Logs:** `/logs/`
- **Documentación:** `./TESTNET_ENDPOINTS.md`
- **Health Check Script:** `./scripts/health-check-monitor.sh`
- **GitHub:** https://github.com/andela bs

---

**Last Updated:** 2025-10-30
**Versión:** 1.0.0 - Production Ready
