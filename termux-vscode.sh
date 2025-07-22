#!/bin/bash

# check curl exist or not
if ! command -v curl >/dev/null 2>&1; then
    echo "Install curl and run the script"
    exit 1
fi

COMMON_SCRIPT_URL="https://scripts.ansari.wtf/base.sh"

source <(curl -s $COMMON_SCRIPT_URL)

cleanup() {
    echo
    echo -e "${YELLOW}Setup interrupted. Cleaning up...${NC}"
    pkill -f code-server 2>/dev/null
    exit 1
}

setup_config() {
    local config_dir="$HOME/.config/code-server"
    local config_file="$config_dir/config.yaml"

    mkdir -p "$config_dir"
    rm -f "$config_file"

    cat > "$config_file" << 'EOF'
bind-addr: 0.0.0.0:8000
auth: none
cert: false
EOF
    return 0
}

wait_for_service() {
    local max_attempts=30
    local attempt=0

    printf "${BLUE}Starting code-server${NC} "

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8000 >/dev/null 2>&1; then
            printf "${GREEN}✓${NC}\n"
            return 0
        fi

        printf "%s" "${SPINNER:$((attempt % ${#SPINNER})):1}"
        sleep 1
        printf "\b"
        attempt=$((attempt + 1))
    done

    printf "${RED}✗${NC}\n"
    echo -e "${RED}Timeout: Code-server failed to start${NC}"
    return 1
}


main(){
    clear
    show_box "Termux VSCode Setup"

    total_steps=5
    current_step=0
    progress_line=5

    initialize_progress_bar
    setup_cleanup_trap cleanup

    run_step "pkg update -y" "Updating package list"
    log_info "Upgrading packages"
    yes " " | pkg upgrade -y > /dev/null 2>&1
    current_step=$((current_step + 1))
    run_step "pkg install tur-repo -y" "Installing tur-repo"
    run_step "pkg install code-server git python3 -y" "Installing code-server, git, and python3"
    run_step "setup_config" "Setting up code-server configuration"

    log_info "Creating LOG directory"
    mkdir -p "$HOME/.code-server-logs"
    log_info "Starting code-server"
    code-server > "$HOME/.code-server-logs/code-server.log" 2>&1 &

    if wait_for_service; then
        show_box "Code-server is running" 40 "GREEN" "Access your code-server at http://localhost:8000"
        if command_exists "termux-open-url"; then
            log_info "Opening in browser"
            termux-open-url http://localhost:8000
        fi
    else
        exit 1
    fi
}

main