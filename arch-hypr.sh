#!/bin/bash

LOGFILE="arch_post_install.log"

sudo -v
( while true; do sudo -n true; sleep 60; done ) & 
sudo_keepalive_pid=$!

PRE_INSTALLED_PKGS=(
    base
    base-devel
    linux
    linux-firmware
    linux-headers
    btrfs-progs
    sudo
    openssh
    neovim
    git
    networkmanager
    zsh
    
    # NVIDIA Drivers
    dkms
    libva-nvidia-driver
    nvidia-open-dkms
)


HYPRLAND_STACK=(
    hyprland-git
    hypridle-git
    hyprlock-git
    hyprpicker-git
    hyprshot
    xdg-desktop-portal-hyprland-git
    swww
    waybar
    cliphist
    rofi
    rofi-calc
    rofimoji
    wtype # rofimoji dependency
)

FONTS_THEME=(
    noto-fonts
    noto-fonts-emoji
    ttf-hack-nerd
    woff2-font-awesome
    nwg-look
)

CLI_TOOLS=(
    bat
    btop
    cpio
    dust
    ddcutil
    eza
    fd
    fzf
    fastfetch
    ripgrep
    tree
    tmux
    zoxide
    stow
    gum
    pacman-contrib
    python-setuptools
    unzip
    xdg-terminal-exec
)

CONTAINERS_VMS=(
    docker
    docker-buildx
    docker-compose
    lazydocker
)

NETWORK_REMOTE=(
    networkmanager
    openssh
    tailscale
    #   rustdesk-bin
    #   tigervnc
    localsend
)

GUI_APPS=(
    ghostty
    chromium
    discord
    evince
    thunar
    visual-studio-code-bin
    zen-browser-bin
    obsidian-bin
    bambustudio-bin
    bruno-bin
)

SECURITY=(
    ufw
    ufw-docker
    polkit-gnome
    keychain
)

SESSION_STACK=(
    sddm
    uwsm
    xorg-xhost
#   sddm dependencies
    qt6-svg
    qt6-multimedia-ffmpeg
)

MEDIA_STACK=(
    pipewire-pulse
    wireplumber
    pavucontrol
    mpv
    imv
)

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

yay_setup(){
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


media_setup(){
    log_info "Setting up Media Applications"
    execute_step "sudo pacman -S --noconfirm --needed ${MEDIA_STACK[*]}" "Installing Media Stack Packages"
    log_info "Media Applications setup completed"

    log_info "Setting up audio with PipeWire"
    execute_step "systemctl --user enable pipewire pipewire-pulse wireplumber" "Enabling PipeWire, PipeWire-Pulse, and WirePlumber services"
    execute_step "systemctl --user start pipewire pipewire-pulse wireplumber" "Starting PipeWire, PipeWire-Pulse, and WirePlumber services"
    execute_step "systemctl --user restart pipewire pipewire-pulse wireplumber" "Restarting PipeWire services to ensure they are running"
    log_info "Audio setup completed"
}

session_setup(){
    log_info "Setting up Session Manager (SDDM)"
    execute_step "sudo pacman -S --noconfirm --needed ${SESSION_STACK[*]}" "Installing Session Stack Packages"
    execute_step "git clone -b wraith https://github.com/The-Robin-Hood/SilentSDDM" "Cloning Wraith SDDM"
    execute_step "sudo mkdir -p /usr/share/sddm/themes/wraith" "Creating SDDM folder"
    execute_step "sudo cp -r SilentSDDM/* /usr/share/sddm/themes/wraith/" "Moving files"
    if [[ -f /etc/sddm.conf ]]; then
        sudo cp -f /etc/sddm.conf /etc/sddm.conf.bk
        sudo rm -rf /etc/sddm.conf
    fi
    execute_step "echo -e '[Theme]\nCurrent=wraith\nGreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/wraith/components/' | sudo tee -a /etc/sddm.conf" "Editing /etc/sddm.conf" 
    execute_step "sudo cp '$HOME/.assets/imgs/dp.jpg' '/usr/share/sddm/faces/$USERNAME.face.icon'" "Setting Avatar for the user"
    log_info "Done with sddm setup"
}

dotfile_setup(){
    log_info "Setting up Dotfiles and Oh-My-Zsh"
    execute_step 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' "Installing oh-my-zsh"
    execute_step "git clone https://github.com/zsh-users/zsh-autosuggestions .oh-my-zsh/custom/plugins/zsh-autosuggestions" "Cloning zsh-autosuggestions plugin"
    execute_step "git clone https://github.com/The-Robin-Hood/dotfiles" "Cloning Dotfiles"
    execute_step "cd dotfiles && stow . --adopt && git restore . && cd .." "Configuring dotfiles"
    log_info "Dotfiles and Oh-My-Zsh setup completed"   
}




main(){
    clear
    ensure_connectivity_and_source
    setup_cleanup_trap cleanup  
    trap cleanup_sudo EXIT
    show_box "Arch Post Installation" 
    
    yay_setup
    
    execute_step "yay -Syu --noconfirm --needed" "Updating System Packages"
    execute_step "yay -S --noconfirm --needed ${PRE_INSTALLED_PKGS[*]}" "Checking Pre-installed Packages"
    execute_step "yay -S --noconfirm --needed ${FONTS_THEME[*]}" "Installing Fonts and Theme Packages"
    execute_step "yay -S --noconfirm --needed ${SECURITY[*]}" "Installing Security Packages"
    execute_step "yay -S --noconfirm --needed ${CLI_TOOLS[*]}" "Installing CLI Tools"
    execute_step "yay -S --noconfirm --needed ${NETWORK_REMOTE[*]}" "Installing Network and Remote Packages"
    execute_step "yay -S --noconfirm --needed ${CONTAINERS_VMS[*]}" "Installing Container and VM Packages"
    execute_step "yay -S --noconfirm --needed ${GUI_APPS[*]}" "Installing GUI Applications"
    execute_step "yay -S --noconfirm --needed ${HYPRLAND_STACK[*]}" "Installing Hyprland and related Packages"

    media_setup
    session_setup
    dotfile_setup

    execute_step "swww img .assets/wallpapers/gwen-stacy.jpg --transition-fps=60 --transition-type=wipe" "Configuring Wallpaper" 
}

main