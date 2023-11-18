#!/bin/bash

# Function to display a spinning wheel loading animation
loading_animation() {
    local spinstr='|/-\'
    while ps -p $1 > /dev/null; do
        printf "[%c] " "$spinstr"
        spinstr=${spinstr#?}${spinstr%???}
        sleep 0.1
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to execute a command with a loading animation and status message
execute_with_loading_animation() {
    local command="$1"
    local description="$2"
    local success_message="$3"

    echo $description

    # Run the command in the background
    $command > /dev/null 2>&1 &

    local pid=$!
    loading_animation $pid

    if [ $? -eq 0 ]; then
        printf "$success_message\n"
    else
        printf "\n%s failed.\n" "$description"
    fi
}

clear
# Update the packages without displaying output
execute_with_loading_animation "pkg update -y" "Updating Packages" "Packages updated successfully"

# Install tur-repo without displaying output
execute_with_loading_animation "pkg install tur-repo -y" "\nInstalling tur-repo" "tur-repo installed successfully"

# Install code-server, git, and python3 without displaying output
execute_with_loading_animation "pkg install code-server git python3 -y" "\nInstalling code-server, git, and python3" "Packages installed successfully"


# change the config.yaml file
mkdir -p ~/.config/code-server
rm -rf ~/.config/code-server/config.yaml
cat <<end > ~/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8000
auth: none
cert: false
end

# clear 
echo "\nInitializing code-server. This might take few seconds...\n"
mkdir -p .code-server-logs
code-server > .code-server-logs/code-server.log 2>&1 &
# wait for code-server to start
sleep 10
# open the browser
termux-open-url http://localhost:8000