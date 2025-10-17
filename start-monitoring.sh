#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/infra/stacks/single-sequencer/docker-compose.monitoring.yml"

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Docker is running"
    
    if ! docker network ls | grep -q "ande-network"; then
        print_warning "ande-network does not exist, creating it..."
        docker network create ande-network
        print_success "ande-network created"
    else
        print_success "ande-network exists"
    fi
}

start_monitoring() {
    print_header "Starting Monitoring Stack"
    
    cd "$SCRIPT_DIR/infra/stacks/single-sequencer"
    
    print_info "Starting Prometheus, Grafana, Node Exporter, and cAdvisor..."
    docker compose -f docker-compose.monitoring.yml up -d
    
    print_info "Waiting for services to be ready..."
    sleep 10
    
    if docker ps | grep -q "prometheus-andechain"; then
        print_success "Prometheus is running"
    else
        print_error "Prometheus failed to start"
        exit 1
    fi
    
    if docker ps | grep -q "grafana-andechain"; then
        print_success "Grafana is running"
    else
        print_error "Grafana failed to start"
        exit 1
    fi
    
    if docker ps | grep -q "node-exporter"; then
        print_success "Node Exporter is running"
    else
        print_warning "Node Exporter failed to start"
    fi
    
    if docker ps | grep -q "cadvisor"; then
        print_success "cAdvisor is running"
    else
        print_warning "cAdvisor failed to start"
    fi
}

check_targets() {
    print_header "Checking Prometheus Targets"
    
    sleep 5
    
    print_info "Waiting for Prometheus to scrape targets..."
    sleep 10
    
    print_info "Checking target status..."
    curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}' 2>/dev/null || print_warning "Could not check targets (jq might not be installed)"
}

show_status() {
    print_header "📊 Monitoring Stack Status"
    
    echo -e "${CYAN}Running Containers:${NC}"
    docker ps --filter "name=prometheus-andechain" --filter "name=grafana-andechain" --filter "name=node-exporter" --filter "name=cadvisor" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo -e "${CYAN}📈 Access URLs:${NC}"
    echo -e "  ${GREEN}Prometheus:${NC}  http://localhost:9090"
    echo -e "  ${GREEN}Grafana:${NC}     http://localhost:3000 (admin/ande_dev_2025)"
    echo -e "  ${GREEN}Node Exporter:${NC} http://localhost:9101/metrics"
    echo -e "  ${GREEN}cAdvisor:${NC}    http://localhost:8080"
    echo ""
    echo -e "${CYAN}🔍 Quick Links:${NC}"
    echo -e "  Prometheus Targets: http://localhost:9090/targets"
    echo -e "  Prometheus Alerts:  http://localhost:9090/alerts"
    echo -e "  Grafana Dashboards: http://localhost:3000/dashboards"
    echo ""
    echo -e "${CYAN}📜 AndeChain Metrics:${NC}"
    echo -e "  EV-Reth:    http://localhost:9001/metrics"
    echo -e "  Sequencer:  http://localhost:26660/metrics"
    echo ""
}

stop_monitoring() {
    print_header "Stopping Monitoring Stack"
    
    cd "$SCRIPT_DIR/infra/stacks/single-sequencer"
    docker compose -f docker-compose.monitoring.yml down
    
    print_success "Monitoring stack stopped"
}

restart_monitoring() {
    stop_monitoring
    sleep 3
    start_monitoring
    show_status
}

show_logs() {
    local service=${1:-all}
    
    cd "$SCRIPT_DIR/infra/stacks/single-sequencer"
    
    case "$service" in
        prometheus)
            docker compose -f docker-compose.monitoring.yml logs -f prometheus
            ;;
        grafana)
            docker compose -f docker-compose.monitoring.yml logs -f grafana
            ;;
        node-exporter)
            docker compose -f docker-compose.monitoring.yml logs -f node-exporter
            ;;
        cadvisor)
            docker compose -f docker-compose.monitoring.yml logs -f cadvisor
            ;;
        all|*)
            docker compose -f docker-compose.monitoring.yml logs -f
            ;;
    esac
}

show_help() {
    echo -e "${BLUE}AndeChain Monitoring Stack Manager${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}start${NC}       - Start the monitoring stack"
    echo -e "  ${GREEN}stop${NC}        - Stop the monitoring stack"
    echo -e "  ${GREEN}restart${NC}     - Restart the monitoring stack"
    echo -e "  ${GREEN}status${NC}      - Show monitoring stack status"
    echo -e "  ${GREEN}logs${NC} [svc]  - Show logs (all, prometheus, grafana, node-exporter, cadvisor)"
    echo -e "  ${GREEN}targets${NC}     - Check Prometheus target status"
    echo -e "  ${GREEN}help${NC}        - Show this help message"
    echo ""
    echo "Examples:"
    echo -e "  ${YELLOW}$0 start${NC}              # Start monitoring"
    echo -e "  ${YELLOW}$0 status${NC}             # Check status"
    echo -e "  ${YELLOW}$0 logs prometheus${NC}    # View Prometheus logs"
    echo ""
}

main() {
    case "${1:-start}" in
        start)
            check_prerequisites
            start_monitoring
            check_targets
            show_status
            ;;
        stop)
            stop_monitoring
            ;;
        restart)
            restart_monitoring
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "${2:-all}"
            ;;
        targets)
            check_targets
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
