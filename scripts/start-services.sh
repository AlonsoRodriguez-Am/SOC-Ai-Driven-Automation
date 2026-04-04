#!/bin/bash
# SOC Automation - Service Management Script
# Manages all SOC services (Wazuh, Zammad, n8n)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service directories
WAZUH_DIR="${REPO_ROOT}/wazuh"
ZAMMAD_DIR="${REPO_ROOT}/zammad"
N8N_DIR="${REPO_ROOT}/n8n"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
SOC Automation Service Management Script v${VERSION}

Usage: $0 [COMMAND] [SERVICE]

Commands:
    start       Start all or specific service
    stop        Stop all or specific service
    restart     Restart all or specific service
    status      Show status of all services
    logs        Show logs (use SERVICE to specify)
    clean       Clean up containers and volumes

Services:
    wazuh       Wazuh SIEM
    zammad      Zammad Ticketing
    n8n         n8n Workflow Engine
    all         All services (default)

Examples:
    $0 start                  # Start all services
    $0 start n8n              # Start only n8n
    $0 status                 # Show status of all
    $0 logs wazuh             # Show Wazuh logs
    $0 restart all            # Restart all services

EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
}

check_service_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_warning "Directory not found: $dir"
        return 1
    fi
    return 0
}

start_service() {
    local service="$1"
    local dir=""

    case "$service" in
        wazuh)
            dir="$WAZUH_DIR"
            ;;
        zammad)
            dir="$ZAMMAD_DIR"
            ;;
        n8n)
            dir="$N8N_DIR"
            ;;
        all)
            start_service "wazuh"
            start_service "zammad"
            start_service "n8n"
            return
            ;;
        *)
            log_error "Unknown service: $service"
            show_help
            exit 1
            ;;
    esac

    if ! check_service_dir "$dir"; then
        log_error "Service directory not found: $dir"
        return 1
    fi

    log_info "Starting $service..."
    cd "$dir"

    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    log_success "$service started"
}

stop_service() {
    local service="$1"
    local dir=""

    case "$service" in
        wazuh)
            dir="$WAZUH_DIR"
            ;;
        zammad)
            dir="$ZAMMAD_DIR"
            ;;
        n8n)
            dir="$N8N_DIR"
            ;;
        all)
            stop_service "n8n"
            stop_service "zammad"
            stop_service "wazuh"
            return
            ;;
        *)
            log_error "Unknown service: $service"
            show_help
            exit 1
            ;;
    esac

    if ! check_service_dir "$dir"; then
        return 1
    fi

    log_info "Stopping $service..."
    cd "$dir"

    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi

    log_success "$service stopped"
}

restart_service() {
    local service="$1"
    log_info "Restarting $service..."
    stop_service "$service"
    sleep 2
    start_service "$service"
}

show_status() {
    log_info "SOC Automation Services Status"
    echo ""

    for service in wazuh zammad n8n; do
        local dir=""
        case "$service" in
            wazuh) dir="$WAZUH_DIR" ;;
            zammad) dir="$ZAMMAD_DIR" ;;
            n8n) dir="$N8N_DIR" ;;
        esac

        if [ -d "$dir" ]; then
            echo -e "${BLUE}$service:${NC}"
            cd "$dir" 2>/dev/null || continue

            if command -v docker-compose &> /dev/null; then
                docker-compose ps 2>/dev/null || echo "  Not running"
            else
                docker compose ps 2>/dev/null || echo "  Not running"
            fi
            echo ""
        fi
    done
}

show_logs() {
    local service="$1"
    local dir=""

    case "$service" in
        wazuh)
            dir="$WAZUH_DIR"
            ;;
        zammad)
            dir="$ZAMMAD_DIR"
            ;;
        n8n)
            dir="$N8N_DIR"
            ;;
        *)
            log_error "Unknown service: $service"
            show_help
            exit 1
            ;;
    esac

    if ! check_service_dir "$dir"; then
        exit 1
    fi

    cd "$dir"

    if command -v docker-compose &> /dev/null; then
        docker-compose logs -f
    else
        docker compose logs -f
    fi
}

clean_services() {
    log_warning "This will stop and remove all containers and volumes!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        log_info "Cleaning up services..."

        stop_service "all"

        log_info "Removing volumes..."
        docker volume ls | grep -E '(wazuh|zammad|n8n)' | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true

        log_success "Cleanup complete"
    else
        log_info "Cleanup cancelled"
    fi
}

main() {
    check_docker

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    COMMAND="$1"
    SERVICE="${2:-all}"

    case "$COMMAND" in
        start)
            start_service "$SERVICE"
            ;;
        stop)
            stop_service "$SERVICE"
            ;;
        restart)
            restart_service "$SERVICE"
            ;;
        status)
            show_status
            ;;
        logs)
            if [ "$SERVICE" = "all" ]; then
                log_error "Please specify a service for logs (wazuh, zammad, n8n)"
                exit 1
            fi
            show_logs "$SERVICE"
            ;;
        clean)
            clean_services
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"