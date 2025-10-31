#!/bin/bash

# Setup de cron job para monitoreo automático de ANDE Chain
# Ejecuta health checks cada 5 minutos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECK_SCRIPT="${SCRIPT_DIR}/health-check-monitor.sh"

# Hacer el script ejecutable
chmod +x "${HEALTH_CHECK_SCRIPT}"

# Crear entrada de cron
CRON_ENTRY="*/5 * * * * cd ${SCRIPT_DIR}/.. && ${HEALTH_CHECK_SCRIPT} >> /dev/null 2>&1"

# Verificar si ya existe
if crontab -l 2>/dev/null | grep -q "${HEALTH_CHECK_SCRIPT}"; then
    echo "El cron job ya está configurado"
else
    # Agregar nuevo cron job
    (crontab -l 2>/dev/null; echo "${CRON_ENTRY}") | crontab -
    echo "✅ Cron job configurado para ejecutarse cada 5 minutos"
    echo "Comando: ${CRON_ENTRY}"
fi

# Mostrar estado del cron
echo ""
echo "Cron jobs activos para ANDE Chain:"
crontab -l 2>/dev/null | grep health-check-monitor || echo "No hay cron jobs específicos"
