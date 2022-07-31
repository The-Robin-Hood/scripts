#!/bin/bash

apt update && apt upgrade -y && apt-get install sudo vim git -y
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source .bashrc
nvm install --lts
curl -fsSL https://code-server.dev/install.sh | sh