#!/bin/bash

LOGFILE="arch_install.log"

ensure_connectivity_and_source(){
    if ! sudo ping -c 3 archlinux.org >/dev/null 2>&1; then
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


gather_user_info(){
    set -e
    log_info "Gathering User Configuration Details."
    execute_with_output "lsblk" "Listing disk partitions"
    prompt_input "Enter the disk to install Arch Linux (eg /dev/sda)" DISK

    if [ -z "$DISK" ]; then
        log_error "No disk specified. Exiting."
        exit 1
    fi

    prompt_input "Enter the hostname" HOSTNAME
    if [ -z "$HOSTNAME" ]; then
        log_error "No hostname specified. Exiting."
        exit 1
    fi

    prompt_input "Enter the username" USERNAME
    if [ -z "$USERNAME" ]; then
        log_error "No username specified. Exiting."
        exit 1 
    fi

    prompt_masked_password "Enter the user password" PASSWORD
    if [ -z "$PASSWORD" ]; then
        log_error "No password specified. Exiting."
        exit 1
    fi  

    prompt_masked_password "Enter the root password" ROOT_PASSWORD
    if [ -z "$ROOT_PASSWORD" ]; then    
        log_error "No root password specified. Exiting."
        exit 1
    fi

    prompt_input "Enter the timezone (e.g., Asia/Kolkata)" TIMEZONE
    if [ -z "$TIMEZONE" ]; then
        log_warning "No timezone specified. Using default 'Asia/Kolkata'."
        TIMEZONE="Asia/Kolkata"
    fi

    clear_screen_from_given_line 8
    log_success "User configuration details collected successfully."
    log true "${CYAN}\nHostname: $HOSTNAME \nUsername: $USERNAME \nDisk: $DISK \nTimezone: $TIMEZONE ${NC}"
}

partition_and_format_disk(){
    log_warning "About to partition the disk. Ensure you have backups of any important data on $DISK."
    log_warning "Will create: 1GB boot partition (EFI), remaining space for root"
    ask_yes_no "Do you want to continue with disk partitioning?" || {
        log_info "Disk partitioning aborted by user."
        exit 0
    } 
    clear_screen_from_given_line 14
    echo
    log_info "Partitioning disk $DISK with Btrfs filesystem."
    execute_step "parted --script $DISK mklabel gpt" "Creating GPT partition table on $DISK"
    execute_step "parted --script $DISK mkpart primary fat32 1MiB 1025MiB" "Creating EFI partition on $DISK"
    execute_step "parted --script $DISK set 1 esp on" "Setting ESP flag on partition 1"
    execute_step "parted --script $DISK mkpart primary btrfs 1025MiB 100%" "Creating Btrfs partition on $DISK"
    execute_with_output "lsblk $DISK" "Listing updated partitions"
    execute_step "mkfs.fat -F32 ${DISK}1" "Formatting EFI partition"
    execute_step "mkfs.btrfs -f ${DISK}2" "Formatting Btrfs partition"

    clear_screen_from_given_line 16
    log_success "Disk partitioning and formatting completed successfully."
}


create_btrfs_subvolumes() {
    echo
    log_info "Creating BTRFS subvolumes - ${DISK}2"
    
    execute_step "mount ${DISK}2 /mnt" "Mounting Btrfs partition"
    execute_step "btrfs subvolume create /mnt/@" "Creating root subvolume"
    execute_step "btrfs subvolume create /mnt/@home" "Creating home subvolume"
    execute_step "btrfs subvolume create /mnt/@log" "Creating log subvolume"
    execute_step "btrfs subvolume create /mnt/@pkg" "Creating package subvolume"
    execute_step "btrfs subvolume create /mnt/@snapshots" "Creating snapshots subvolume"
    execute_step "umount /mnt" "Unmounting Btrfs partition"
    
    clear_screen_from_given_line 19

    log_success "BTRFS subvolumes created successfully."
}

mount_filesystem(){
    echo
    log_info "Mounting BTRFS subvolumes"
    execute_step "mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@ ${DISK}2 /mnt" "Mounting root subvolume"
    execute_step "mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}" "Creating mount directories"
    execute_step "mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@home ${DISK}2 /mnt/home" "Mounting home subvolume"
    execute_step "mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@log ${DISK}2 /mnt/var/log" "Mounting log subvolume"
    execute_step "mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@pkg ${DISK}2 /mnt/var/cache/pacman/pkg" "Mounting package subvolume"
    execute_step "mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots ${DISK}2 /mnt/.snapshots" "Mounting snapshots subvolume"
    execute_step "mount ${DISK}1 /mnt/boot" "Mounting EFI partition"
    clear_screen_from_given_line 22
    log_success "BTRFS subvolumes mounted successfully."
}

install_base_system(){
    echo
    log_info "Installing base system packages"
    log_warning "About to install base system packages. This may take a while."
    execute_step "pacstrap -K /mnt base base-devel linux linux-headers linux-firmware btrfs-progs neovim openssh networkmanager sudo git zsh" "Installing base system packages"
    clear_screen_from_given_line 25
    log_success "Base system packages installed successfully."
}

generate_fstab(){
    echo
    log_info "Generating fstab file"
    execute_step "genfstab -U /mnt >> /mnt/etc/fstab" "Generating fstab"
    clear_screen_from_given_line 28
    log_success "fstab file generated successfully."
}


create_chroot_script() {
    echo
    log_info "Creating chroot setup script"
       cat <<CHROOT_EOF > /mnt/setup_chroot.sh
#!/bin/bash

source <( curl -s $COMMON_SCRIPT_URL )
LOGFILE="/chroot_setup_arch.log"

configure_system_basics() {
    log_info "Configuring system basics"
    execute_step "echo '$HOSTNAME' > /etc/hostname" "Setting up hostname - $HOSTNAME"
    execute_step "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime" "Setting timezone to $TIMEZONE"
    execute_step "hwclock --systohc" "Synchronizing hardware clock"
    execute_step "sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen" "Enabling en_US.UTF-8 locale"
    execute_step "locale-gen" "Generating locales"
    execute_step "echo 'LANG=en_US.UTF-8' > /etc/locale.conf" "Setting system locale"
    log_success "System basics configured successfully."
}

configure_initramfs() {
    log_info "Configuring initramfs for Btrfs"
    execute_step "sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf" "Configuring initramfs for Btrfs"
    echo "KEYMAP=us" > /etc/vconsole.conf
    execute_step "mkinitcpio -P" "Generating initramfs"
    log_success "Initramfs configured successfully."
}

configure_initramfs_nvidia() {
    log_info "Configuring initramfs for Btrfs NVIDIA"
    execute_step "sed -i 's/^MODULES=(btrfs)/MODULES=(btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf" "Configuring initramfs for Btrfs"
    execute_step "mkinitcpio -P" "Generating initramfs"
    log_success "Initramfs configured successfully."
}

setup_users() {
    log_info "Setting up users"
    execute_step "echo -e '$ROOT_PASSWORD\n$ROOT_PASSWORD' | passwd root" "Setting root password"   
    execute_step "useradd -m -G wheel -s /bin/bash $USERNAME" "Creating user $USERNAME"
    execute_step "echo -e '$PASSWORD\n$PASSWORD' | passwd $USERNAME" "Setting user password for $USERNAME"
    execute_step "echo '$USERNAME ALL=(ALL) ALL' >> /etc/sudoers.d/$USERNAME" "Adding $USERNAME to sudoers"
    log_success "Users set up successfully."
}

setup_bootloader() {
    log_info "Setting up bootloader"

    execute_step "bootctl install" "Installing bootctl"
    execute_step "mkdir -p /boot/loader/entries" "Creating boot loader entries"

    PARTUUID=\$(blkid -s PARTUUID -o value ${DISK}2)
    cat << EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=\$PARTUUID rootflags=subvol=@ rw nvidia_drm.modeset=1 quiet splash
EOF

    log_success "Bootloader set up successfully."
}

setup_nvidia_packages() {
    log_info "Setting up Nvidia packages"
    execute_step "pacman -S dkms libva-nvidia-driver nvidia-open-dkms --noconfirm" "Installing Nvidia packages (OSS version)"
    log_success "Nvidia Packages installed successfully."
}

enable_services() {
    log_info "Enabling essential services"
    execute_step "systemctl enable NetworkManager" "Enabling NetworkManager"
    execute_step "systemctl enable sshd" "Enabling SSH daemon"
    log_success "Essential services enabled successfully."
}

log_info "==== Starting Arch Linux Chroot Setup ===="

configure_system_basics
configure_initramfs
setup_users
setup_bootloader
ask_yes_no "Do you want to install Nvidia Packages?" && {
    setup_nvidia_packages
    configure_initramfs_nvidia
} 
enable_services

log_success "Chroot setup completed successfully."
CHROOT_EOF

    chmod +x /mnt/setup_chroot.sh
    log_success "Chroot setup script created successfully."
}

append_chroot_log_to_main_log() {
    log_info "Copying chroot log to main log"
    if [ -f /mnt/chroot_setup_arch.log ]; then
        cat /mnt/chroot_setup_arch.log >> $LOGFILE
        log_info "Chroot setup log copied to $LOGFILE"
    else
        log_warning "Chroot setup log not found."
    fi
}

main(){
    clear
    ensure_connectivity_and_source
    setup_cleanup_trap cleanup
    show_box "Arch Installation" 
    log_info "Starting Arch Linux installation process."
    gather_user_info
    partition_and_format_disk
    create_btrfs_subvolumes
    mount_filesystem
    install_base_system
    generate_fstab
    create_chroot_script
    arch-chroot /mnt /setup_chroot.sh
    append_chroot_log_to_main_log
    log_success "Arch Linux installation completed successfully."
}


main