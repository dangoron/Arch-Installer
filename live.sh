#!/bin/zsh

color() {
    case $1 {
        (red) echo -e "\033[31m$2\033[0m" ;;
        (green) echo -e "\033[32m$2\033[0m" ;;
    }
}

colorread() {
    unset $3
    vared -p "`color $1 $2`" -c $3
}

partition() {
    if [[ $1 == */* ]] { other=$1 } else { other=/$1 }
    fdisk -l
    colorread green "Input the partition like /dev/sdX:" OTHER
    colorread green "Format it? y)yes ENTER)no:" tmp
    if [[ $tmp == y ]] {
        umount $OTHER > /dev/null 2>&1
        color green "Input the filesystem's num to format it"
        select type ( ext2 ext3 ext4 btrfs xfs jfs fat swap ) {
            echo "$type selected"
            case $type {
                (ext2) ;& (ext3) ;& (ext4) ;& (jfs) mkfs.$type $OTHER ;;
                (btrfs) ;& (xfs) mkfs.$type $OTHER -f ;;
                (fat) mkfs.fat -F32 $OTHER ;;
                (swap)
                    swapoff $OTHER > /dev/null 2>&1
                    mkswap $OTHER -f
                ;;
                (*) color red "Error! Please input the num again" ;;
            }
            break
        }
    }
    if [[ $other == "/swap" ]] {
        swapon $OTHER
    } else {
        umount $OTHER > /dev/null 2>&1
        mkdir /mnt$other
        mount $OTHER /mnt$other
    }
}

prepare() {
    colorread green "Do you want to adjust the partition? y)yes ENTER)no:" tmp
    if [[ $tmp == y ]] { cfdisk }
    fdisk -l
    colorread green "Input the ROOT(/) parition like /dev/sdX:" ROOT
    colorread green "Format it? y)yes ENTER)no:" tmp
    if [[ $tmp == y ]] {
        umount $ROOT > /dev/null 2>&1
        color green "Input the filesystem's num to format it:"
        select type ( ext4 btrfs xfs jfs ) {
            echo "$type selected"
            case $type {
                (btrfs) ;& (xfs) mkfs.$type $ROOT -f ;;
                (*) mkfs.$type $ROOT ;;
            }
            break
        }
    }
    mount $ROOT /mnt
    colorread green "Do you have another mount point? if so please input it, such as /boot /home and swap or just ENTER to quit:" other
    while [[ -n $other ]] {
        partition $other
        colorread green "Still have another mount point? input it or just ENTER to quit:" other
    }
}

install() {
    color green "Please choose your country (for Generate the pacman mirror list"
    select COUNTRY ("AU" "AT" "BD" "BY" "BE" "BA" "BR" "BG" "CA" "CL" "CN" "CO" "HR" "CZ" "DK" "EC" "FI" "FR" "DE" "GR" "HK" "HU" "IS" "IN" "ID" "IR" "IE" "IL" "IT" "JP" "KZ" "LV" "LT" "LU" "MK" "MX" "AN" "NC" "NZ" "NO" "PH" "PL" "PT" "QA" "RO" "RU" "RS" "SG" "SK" "SI" "ZA" "KR" "ES" "SE" "CH" "TW" "TH" "TR" "UA" "GB" "US" "VN"){
        mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
        color green "Generating mirror list , Please wait"
        wget https://www.archlinux.org/mirrorlist/\?country=$COUNTRY -O /etc/pacman.d/mirrorlist.new
        sed -i 's/#Server/Server/g' /etc/pacman.d/mirrorlist.new
        rankmirrors -n 3 /etc/pacman.d/mirrorlist.new > /etc/pacman.d/mirrorlist
        chmod +r /etc/pacman.d/mirrorlist
        break
    }
    pacstrap /mnt base base-devel --force
    genfstab -U -p /mnt > /mnt/etc/fstab
}

config() {
    wget https://raw.githubusercontent.com/dangoron/Arch-Installer/master/install_zsh.sh -O /mnt/root/install_zsh.sh
    wget https://raw.githubusercontent.com/dangoron/Arch-Installer/master/config.sh -O /mnt/root/config.sh
    chmod +x /mnt/root/install_zsh.sh /mnt/root/config.sh
    arch-chroot /mnt "/root/install_zsh.sh"
}

if [[ -n $1 ]] {
    case $1 {
        (prepare) ;& (install) ;& (config) $1 ;;
        (--help)
            color red "prepare: prepare disk and partition\ninstall: install the base system\nconfig: chroot into the system and deploy config"
        ;;
        (*)
            color red "Error !\nprepare: prepare disk and partition\ninstall: install the base system\nconfig: chroot into the system and deploy config"
        ;;
    }
} else {
    prepare
    install
    config
}
