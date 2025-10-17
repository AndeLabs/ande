#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_status() {
    print_header "📊 Estado del Sistema AndeChain"
    
    # Celestia Status
    echo -e "${CYAN}🌙 Celestia Light Node:${NC}"
    if pgrep -f "celestia light start" > /dev/null; then
        PID=$(pgrep -f "celestia light start")
        echo -e "  Estado: ${GREEN}✅ Corriendo (PID: $PID)${NC}"
        echo -e "  RPC: ${GREEN}http://localhost:26658${NC}"
        
        # Get block height
        HEIGHT=$(curl -s http://localhost:26658/header/synced 2>/dev/null | grep -o '"height":"[0-9]*"' | grep -o '[0-9]*' || echo "N/A")
        echo -e "  Altura: ${GREEN}$HEIGHT${NC}"
    else
        echo -e "  Estado: ${RED}❌ No está corriendo${NC}"
    fi
    
    echo ""
    
    # AndeChain EV-Reth
    echo -e "${CYAN}⚡ AndeChain EV-Reth:${NC}"
    if docker ps | grep -q "ev-reth-sequencer"; then
        echo -e "  Estado: ${GREEN}✅ Corriendo${NC}"
        echo -e "  RPC: ${GREEN}http://localhost:8545${NC}"
        
        # Get block number
        BLOCK=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | grep -o '"result":"0x[0-9a-f]*"' | grep -o '0x[0-9a-f]*' || echo "N/A")
        if [ "$BLOCK" != "N/A" ]; then
            BLOCK_DEC=$((16#${BLOCK#0x}))
        else
            BLOCK_DEC="N/A"
        fi
        echo -e "  Altura: ${GREEN}$BLOCK_DEC ($BLOCK)${NC}"
        
        # Health
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' ev-reth-sequencer 2>/dev/null || echo "N/A")
        echo -e "  Salud: ${GREEN}$HEALTH${NC}"
    else
        echo -e "  Estado: ${RED}❌ No está corriendo${NC}"
    fi
    
    echo ""
    
    # Sequencer
    echo -e "${CYAN}🔗 AndeChain Sequencer:${NC}"
    if docker ps | grep -q "single-sequencer"; then
        echo -e "  Estado: ${GREEN}✅ Corriendo${NC}"
        echo -e "  Rollkit: ${GREEN}http://localhost:26660${NC}"
        echo -e "  RPC: ${GREEN}http://localhost:7331${NC}"
    else
        echo -e "  Estado: ${RED}❌ No está corriendo${NC}"
    fi
    
    echo ""
    
    # Monitoring Stack Status
    echo -e "${CYAN}📊 Monitoring Stack:${NC}"
    if docker ps | grep -q "prometheus-andechain"; then
        echo -e "  Prometheus: ${GREEN}✅ Corriendo (http://localhost:9090)${NC}"
    else
        echo -e "  Prometheus: ${RED}❌ No está corriendo${NC}"
        echo -e "  ${YELLOW}💡 Inicia con: ./start-monitoring.sh start${NC}"
    fi
    
    if docker ps | grep -q "grafana-andechain"; then
        echo -e "  Grafana: ${GREEN}✅ Corriendo (http://localhost:3000)${NC}"
        echo -e "  ${CYAN}  Usuario: admin / Contraseña: ande_dev_2025${NC}"
    else
        echo -e "  Grafana: ${RED}❌ No está corriendo${NC}"
    fi
    
    echo ""
    
    # Metrics Endpoints
    echo -e "${CYAN}📈 Endpoints de Métricas:${NC}"
    echo -e "  EV-Reth: ${GREEN}http://localhost:9001/metrics${NC}"
    echo -e "  Sequencer: ${GREEN}http://localhost:26660/metrics${NC}"
    echo -e "  Node Exporter: ${GREEN}http://localhost:9101/metrics${NC}"
    echo -e "  cAdvisor: ${GREEN}http://localhost:8080${NC}"
    
    echo ""
}

show_logs() {
    case "$1" in
        celestia)
            print_header "🌙 Logs de Celestia Light Node"
            echo -e "${YELLOW}Mostrando últimas 50 líneas (Ctrl+C para salir)${NC}"
            echo ""
            tail -f /Users/munay/dev/ande-labs/celestia-setup/celestia-light.log
            ;;
        reth)
            print_header "⚡ Logs de EV-Reth Sequencer"
            echo -e "${YELLOW}Mostrando logs en vivo (Ctrl+C para salir)${NC}"
            echo ""
            docker logs -f ev-reth-sequencer
            ;;
        sequencer)
            print_header "🔗 Logs de Rollkit Sequencer"
            echo -e "${YELLOW}Mostrando logs en vivo (Ctrl+C para salir)${NC}"
            echo ""
            docker logs -f single-sequencer
            ;;
        all)
            print_header "📜 Todos los Logs (multiplexado)"
            echo -e "${YELLOW}Mostrando logs de todos los servicios (Ctrl+C para salir)${NC}"
            echo ""
            
            # Crear named pipes para multiplexar
            tail -f /Users/munay/dev/ande-labs/celestia-setup/celestia-light.log 2>/dev/null | sed "s/^/[${CYAN}CELESTIA${NC}] /" &
            PID1=$!
            
            docker logs -f ev-reth-sequencer 2>&1 | sed "s/^/[${GREEN}EV-RETH${NC}] /" &
            PID2=$!
            
            docker logs -f single-sequencer 2>&1 | sed "s/^/[${MAGENTA}SEQUENCER${NC}] /" &
            PID3=$!
            
            trap "kill $PID1 $PID2 $PID3 2>/dev/null; exit" INT TERM
            wait
            ;;
        *)
            echo -e "${RED}Servicio no reconocido: $1${NC}"
            echo ""
            echo "Servicios disponibles:"
            echo "  celestia   - Celestia Light Node"
            echo "  reth       - EV-Reth Sequencer"
            echo "  sequencer  - Rollkit Sequencer"
            echo "  all        - Todos los servicios"
            exit 1
            ;;
    esac
}

show_blocks() {
    print_header "📦 Monitor de Bloques en Tiempo Real"
    echo -e "${YELLOW}Actualizando cada 5 segundos (Ctrl+C para salir)${NC}"
    echo ""
    
    while true; do
        clear
        print_header "📦 Monitor de Bloques - $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Celestia
        echo -e "${CYAN}🌙 Celestia Mocha-4:${NC}"
        CEL_HEIGHT=$(curl -s http://localhost:26658/header/synced 2>/dev/null | grep -o '"height":"[0-9]*"' | grep -o '[0-9]*' || echo "Error")
        echo -e "  Altura: ${GREEN}$CEL_HEIGHT${NC}"
        
        # AndeChain
        echo -e "\n${CYAN}⚡ AndeChain:${NC}"
        BLOCK_HEX=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | grep -o '"result":"0x[0-9a-f]*"' | grep -o '0x[0-9a-f]*' || echo "Error")
        
        if [ "$BLOCK_HEX" != "Error" ]; then
            BLOCK_DEC=$((16#${BLOCK_HEX#0x}))
            echo -e "  Altura: ${GREEN}$BLOCK_DEC${NC} (${BLUE}$BLOCK_HEX${NC})"
            
            # Get latest block details
            BLOCK_INFO=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
                -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$BLOCK_HEX\",false],\"id\":1}" 2>/dev/null)
            
            TX_COUNT=$(echo "$BLOCK_INFO" | grep -o '"transactions":\[[^]]*\]' | grep -o '"0x[^"]*"' | wc -l | tr -d ' ')
            TIMESTAMP=$(echo "$BLOCK_INFO" | grep -o '"timestamp":"0x[0-9a-f]*"' | grep -o '0x[0-9a-f]*')
            
            if [ ! -z "$TIMESTAMP" ]; then
                TIMESTAMP_DEC=$((16#${TIMESTAMP#0x}))
                BLOCK_TIME=$(date -r $TIMESTAMP_DEC '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")
                echo -e "  Transacciones: ${GREEN}$TX_COUNT${NC}"
                echo -e "  Timestamp: ${GREEN}$BLOCK_TIME${NC}"
            fi
        else
            echo -e "  ${RED}Error obteniendo información${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}Próxima actualización en 5 segundos...${NC}"
        sleep 5
    done
}

show_metrics() {
    print_header "📊 Métricas de AndeChain en Tiempo Real"
    
    echo -e "${CYAN}Consultando métricas...${NC}"
    echo ""
    
    # EV-Reth Metrics
    echo -e "${GREEN}⚡ EV-Reth Metrics:${NC}"
    if curl -s http://localhost:9001/metrics > /dev/null 2>&1; then
        echo -e "  Endpoint: ${GREEN}✅ Disponible${NC}"
        echo -e "  URL: http://localhost:9001/metrics"
        
        BLOCK_COUNT=$(curl -s http://localhost:9001/metrics | grep "^reth_blockchain_blocks_total" | awk '{print $2}' || echo "N/A")
        echo -e "  Bloques totales: ${GREEN}$BLOCK_COUNT${NC}"
        
        TX_PENDING=$(curl -s http://localhost:9001/metrics | grep "^reth_transaction_pool_pending_transactions" | awk '{print $2}' || echo "N/A")
        echo -e "  Transacciones pendientes: ${GREEN}$TX_PENDING${NC}"
    else
        echo -e "  Endpoint: ${RED}❌ No disponible${NC}"
    fi
    
    echo ""
    
    # Sequencer Metrics
    echo -e "${GREEN}🔗 Sequencer Metrics:${NC}"
    if curl -s http://localhost:26660/metrics > /dev/null 2>&1; then
        echo -e "  Endpoint: ${GREEN}✅ Disponible${NC}"
        echo -e "  URL: http://localhost:26660/metrics"
    else
        echo -e "  Endpoint: ${RED}❌ No disponible${NC}"
    fi
    
    echo ""
    
    # Prometheus Status
    echo -e "${GREEN}📈 Prometheus:${NC}"
    if docker ps | grep -q "prometheus-andechain"; then
        echo -e "  Status: ${GREEN}✅ Corriendo${NC}"
        echo -e "  URL: http://localhost:9090"
        echo -e "  Targets: http://localhost:9090/targets"
    else
        echo -e "  Status: ${RED}❌ No está corriendo${NC}"
        echo -e "  ${YELLOW}💡 Inicia con: ./start-monitoring.sh start${NC}"
    fi
    
    echo ""
    
    # Grafana Status
    echo -e "${GREEN}📊 Grafana:${NC}"
    if docker ps | grep -q "grafana-andechain"; then
        echo -e "  Status: ${GREEN}✅ Corriendo${NC}"
        echo -e "  URL: http://localhost:3000"
        echo -e "  Usuario: admin"
        echo -e "  Contraseña: ande_dev_2025"
    else
        echo -e "  Status: ${RED}❌ No está corriendo${NC}"
        echo -e "  ${YELLOW}💡 Inicia con: ./start-monitoring.sh start${NC}"
    fi
    
    echo ""
}

show_help() {
    echo -e "${BLUE}AndeChain Log Monitor${NC}"
    echo ""
    echo "Uso: $0 <comando> [opciones]"
    echo ""
    echo "Comandos:"
    echo -e "  ${GREEN}status${NC}              - Mostrar estado de todos los servicios"
    echo -e "  ${GREEN}logs <servicio>${NC}     - Ver logs de un servicio específico"
    echo -e "  ${GREEN}blocks${NC}              - Monitor de bloques en tiempo real"
    echo -e "  ${GREEN}metrics${NC}             - Mostrar información de métricas"
    echo -e "  ${GREEN}help${NC}                - Mostrar esta ayuda"
    echo ""
    echo "Servicios para logs:"
    echo -e "  ${CYAN}celestia${NC}            - Celestia Light Node"
    echo -e "  ${CYAN}reth${NC}                - EV-Reth Sequencer"
    echo -e "  ${CYAN}sequencer${NC}           - Rollkit Sequencer"
    echo -e "  ${CYAN}all${NC}                 - Todos los servicios (multiplexado)"
    echo ""
    echo "Ejemplos:"
    echo -e "  ${YELLOW}$0 status${NC}"
    echo -e "  ${YELLOW}$0 logs celestia${NC}"
    echo -e "  ${YELLOW}$0 logs all${NC}"
    echo -e "  ${YELLOW}$0 blocks${NC}"
    echo -e "  ${YELLOW}$0 metrics${NC}"
    echo ""
    echo "Monitoring:"
    echo -e "  ${YELLOW}./start-monitoring.sh start${NC}   - Iniciar stack de monitoreo"
    echo -e "  ${YELLOW}./start-monitoring.sh status${NC}  - Ver estado del monitoreo"
}

# Main
case "${1:-status}" in
    status)
        show_status
        ;;
    logs)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Debes especificar un servicio${NC}"
            echo ""
            show_help
            exit 1
        fi
        show_logs "$2"
        ;;
    blocks)
        show_blocks
        ;;
    metrics)
        show_metrics
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Comando no reconocido: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
