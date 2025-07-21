#!/bin/bash

# ============================================================================
# Common Functions Library
# ============================================================================
# Usage: source common_functions.sh
# This file contains reusable functions for bash scripts

# Colors for better visual feedback
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export WHITE='\033[1;37m'
export NC='\033[0m'

# Animation characters - different styles available
export SPINNER_DOTS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
export SPINNER_CIRCLE="◐◓◑◒"
export SPINNER_BLOCKS="⣾⣽⣻⢿⡿⣟⣯⣷"

# Default spinner style
SPINNER="$SPINNER_DOTS"

# Logging functions
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log_info() {
    echo -e "${BLUE}[$(timestamp)] [ INFO  ]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(timestamp)] [SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(timestamp)] [ WARN  ]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(timestamp)] [ ERROR ]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-}" = "true" ]; then
        echo -e "${CYAN}[$(timestamp)] [ DEBUG ]${NC} $1"
    fi
}

set_spinner_style() {
    case "$1" in
        "dots") SPINNER="$SPINNER_DOTS" ;;
        "circle") SPINNER="$SPINNER_CIRCLE" ;;
        "blocks") SPINNER="$SPINNER_BLOCKS" ;;
        *) SPINNER="$SPINNER_DOTS" ;;
    esac
}

show_spinner() {
    local pid=$1
    local message="$2"
    local i=0
    
    printf "${BLUE}%s${NC} " "$message"
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}%s${NC} %s" "$message" "${SPINNER:$i:1}"
        i=$(( (i + 1) % ${#SPINNER} ))
        sleep 0.1
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${BLUE}%s${NC} ${GREEN}✓${NC}\n" "$message"
        return 0
    else
        printf "\r${BLUE}%s${NC} ${RED}✗${NC}\n" "$message"
        return 1
    fi
}

# jus execute the cmd given with spinner
execute_step() {
    local command="$1"
    local message="$2"
    local allow_failure="${3:-false}"
    
    # command in background, suppress all output
    eval "$command" >/dev/null 2>&1 &
    local pid=$!
    
    if show_spinner $pid "$message"; then
        return 0
    else
        if [ "$allow_failure" = "true" ]; then
            log_warning "$message failed (continuing anyway)"
            return 1
        else
            log_error "$message failed"
            exit 1
        fi
    fi
}

# same as above but finally spits the output
execute_with_output() {
    local command="$1"
    local message="$2"
    local temp_file
    temp_file=$(mktemp)
    
    eval "$command" > "$temp_file" 2>&1 &
    local pid=$!
    
    if show_spinner $pid "$message"; then
        cat "$temp_file"
        rm -f "$temp_file"
        return 0
    else
        echo -e "${RED}Command output:${NC}"
        cat "$temp_file"
        rm -f "$temp_file"
        return 1
    fi
}

# display header - success - message 
show_box() {
    local title="$1"
    local width="${2:-40}"
    local color="${3:-YELLOW}"
    local details="$4"

    local color_code="${!color:-$YELLOW}"

    echo
    printf "${color_code}╔"
    printf "═%.0s" $(seq 1 $((width - 2)))
    printf "╗${NC}\n"

    local padding=$(( (width - ${#title} - 2) / 2 ))
    printf "${color_code}║"
    printf " %.0s" $(seq 1 $padding)
    printf "%s" "$title"
    printf " %.0s" $(seq 1 $((width - ${#title} - padding - 2)))
    printf "║${NC}\n"

    printf "${color_code}╚"
    printf "═%.0s" $(seq 1 $((width - 2)))
    printf "╝${NC}\n"

    if [ -n "$details" ]; then
        echo
        echo "$details"
    fi

    echo
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_directory() {
    local dir="$1"
    local message="${2:-Creating directory: $dir}"
    
    if [ ! -d "$dir" ]; then
        printf "${BLUE}%s${NC} " "$message"
        if mkdir -p "$dir" 2>/dev/null; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            log_error "Failed to create directory: $dir"
            return 1
        fi
    fi
}

backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"
    
    if [ -f "$file" ]; then
        local backup_file="${file}${backup_suffix}"
        printf "${BLUE}Backing up %s${NC} " "$(basename "$file")"
        if cp "$file" "$backup_file" 2>/dev/null; then
            printf "${GREEN}✓${NC}\n"
        else
            printf "${RED}✗${NC}\n"
            return 1
        fi
    fi
}

show_progress() {
    local current="$1"
    local total="$2" 
    local message="${3:-Progress}"
    local width=24
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}%s${NC} [" "$message"
    printf "${GREEN}█%.0s${NC}" $(seq 1 $filled)
    printf "░%.0s" $(seq 1 $empty)
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        printf " ${GREEN}✓${NC}\n"
    fi
}

ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local response
    
    while true; do
        if [ "$default" = "y" ]; then
            printf "${YELLOW}%s [Y/n]: ${NC}" "$question"
        else
            printf "${YELLOW}%s [y/N]: ${NC}" "$question"
        fi
        
        read -r response
        response=${response:-$default}
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo -e "${RED}Please answer yes or no.${NC}" ;;
        esac
    done
}

setup_cleanup_trap() {
    local cleanup_function="$1"

    if ! command_exists "$cleanup_function"; then
        log_error "Cleanup function '$cleanup_function' does not exist"
        return 1
    fi
    
    cleanup_handler() {
        echo
        log_warning "Script ended. Running cleanup..."
        "$cleanup_function"
        exit 1
    }
    
    trap cleanup_handler INT TERM 
}

validate_url() {
    local url="$1"
    if [[ $url =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

check_disk_space() {
    local required_mb="$1"
    local path="${2:-.}"
    
    if command_exists df; then
        local available_kb
        available_kb=$(df "$path" | awk 'NR==2 {print $4}')
        local available_mb=$((available_kb / 1024))
        
        if [ "$available_mb" -lt "$required_mb" ]; then
            log_warning "Low disk space: ${available_mb}MB available, ${required_mb}MB required"
            return 1
        fi
    fi
    return 0
}

# ========= THIS FUNCTION IS FOR SPECIFIC PURPOSE OF SHOWING PROGRESS BAR AT TOP==========
initialize_progress_bar(){
    printf "\033[${progress_line};1H"
    show_progress "$current_step" "$total_steps"
    echo -e "\n\n"
}

run_step() {
    local cmd="$1"
    local msg="$2"
    execute_step "$cmd" "$msg"
    ((current_step++))
    printf "\033[s"                  # Save cursor
    printf "\033[${progress_line};1H"
    show_progress "$current_step" "$total_steps"
    printf "\033[u"                  # Restore cursor
}
# ================================================


init_common_functions() {
    set_spinner_style "dots"
    export -f show_spinner show_box show_progress
    export -f log_info log_success log_warning log_error log_debug
    export -f execute_step execute_with_output command_exists 
    export -f ensure_directory backup_file ask_yes_no validate_url
    export -f check_disk_space
}

init_common_functions