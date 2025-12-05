#!/bin/bash

LOGFILE="arch_post_install.log"

sudo -v
( while true; do sudo -n true; sleep 60; done ) & 
sudo_keepalive_pid=$!

cleanup_sudo() {
    kill "$sudo_keepalive_pid"
}

ensure_connectivity_and_source(){
    if ! ping -c 3 archlinux.org >/dev/null 2>&1; then
        echo "Network connectivity check failed. Please ensure you are connected to the internet."
        exit 1
    fi 
    
    if ! command -v curl >/dev/null 2>&1; then
        echo "Install curl and run the script"
        exit 1
    fi

    COMMON_SCRIPT_URL="https://scripts.ansari.wtf/base.sh"
    source <(curl -s $COMMON_SCRIPT_URL)
}

cleanup(){
    echo
    echo -e "${YELLOW}Setup interrupted. Cleaning up...${NC}"
    exit 1
}

yay_install(){
    if ! yay --version >/dev/null 2>&1; then
        execute_step "git --version" "Precheck Git installed"
        execute_step "git clone https://aur.archlinux.org/yay.git" "Cloning yay from git"
        log_info "Installing yay"
        (cd yay && makepkg -si --noconfirm) && rm -rf yay
        clear_screen_from_given_line 10
        log_info "yay installed successfully"
    else 
        log_info "yay is already installed.."
    fi
}


main(){
    clear
    ensure_connectivity_and_source
    setup_cleanup_trap cleanup  
    trap cleanup_sudo EXIT
    show_box "Arch Post Installation" 
    yay_install
    execute_step "yay -S --noconfirm fzf fd tree stow keychain zsh unzip ghostty tmux zoxide neovim cliphist pacman-contrib --needed" "Installing Development Essentials"
    execute_step "yay -S --noconfirm rofi bat polkit-gnome ttf-font-awesome noto-fonts noto-fonts-emoji --needed" "Installing Minimal GUI Tools"
    execute_step "yay -S --noconfirm bruno-bin obsidian-bin visual-studio-code-bin zen-browser-bin" "Installing Prebuild binaries"
    execute_step "yay -S --noconfirm hyprland-git" "Installing Hyprland"
    # execute_step "yay -S --noconfirm hypridle hyprlock-git hyprshot ags-hyprpanel-git swww --needed" "Installing Hyprland Environment"
    execute_step 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' "Installing oh-my-zsh"
    execute_step "git clone https://github.com/zsh-users/zsh-autosuggestions .oh-my-zsh/custom/plugins/zsh-autosuggestions" "Cloning zsh-autosuggestions plugin"
    execute_step "git clone https://github.com/The-Robin-Hood/dotfiles" "Cloning Dotfiles"
    execute_step "cd dotfiles && stow . --adopt && git restore . && cd .." "Configuring dotfiles"
    # execute_step "swww img .assets/wallpapers/gwen-stacy.jpg --transition-fps=60 --transition-type=wipe" "Configuring Wallpaper" 
}

main

