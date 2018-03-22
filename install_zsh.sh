#!/bin/bash

pacman -S --noconfirm zsh
chsh -s /usr/bin/zsh
zsh /root/config.sh
