#!/bin/zsh

set -e

color() {
    case $1 {
        (red) echo -e "\033[31m$2\033[0m" ;;
        (yellow) echo -e "\033[33m$2\033[0m" ;;
    }
}

colorread() {
    unset $3
    vared -p "`color $1 $2`" -c $3
}

config_base(){
    colorread yellow "Input your hostname:" TMP
    echo $TMP > /etc/hostname
    color yellow "Set your root passwd:"
    passwd
}

config_locale(){
    color yellow "Please choose your locale time"
    select ZONE (`ls /usr/share/zoneinfo`) {
        if [[ -d "/usr/share/zoneinfo/$ZONE" ]] {
            select CITY (`ls usr/share/zoneinfo/$ZONE`) {
                ln -sf /usr/share/zoneinfo/$ZONE/$CITY /etc/localtime
                break
            }
        } else {
            ln -sf /usr/share/zoneinfo/$ZONE /etc/localtime
        }
        break
    }
    hwclock --systohc --utc
    for LANG (en_US.UTF-8 zh_CN.UTF-8) {
        sed -i "s/\#$LANG UTF-8/$LANG UTF-8/" /etc/locale.gen
    }
    locale-gen
    color yellow "Choose your system language"
    select LANG (en_US.UTF-8 zh_CN.UTF-8) {
        echo "LANG=$LANG" > /etc/locale.conf
        break
    }
}

install_grub(){
    if [[ `mount` == *efivarfs* ]] {
        pacman -S --noconfirm grub efivarfs -y
        grub-install --target=`uname -m`-efi --efi-directory=/boot --bootloader-id=Arch
        grub-mkconfig -o /boot/grub/grub.cfg
    } else {
        pacman -S --noconfirm grub
        fdisk -l
        colorread yellow "Input the disk you want to install grub like /dev/sdX:" TMP
        grub-install --target=i386-pc $TMP
        grub-mkconfig -o /boot/grub/grub.cfg
    }
}

install_bootctl(){
    if [[ `mount` == *efivarfs* ]] {
        colorread yellow "Please enter your EFI system partition (ESP) mountpoint like /boot:" ESP
        colorread yellow "Please enter your root disk like /dev/sdaX:" ROOT
        bootctl --path=$ESP install
        cp /usr/share/systemd/bootctl/loader.conf /boot/loader/
        echo -e "timeout 4\neditor 0" >> /boot/loader/loader.conf
        echo -e "title  Arch Linux\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img" > /boot/loader/entries/arch.conf
        echo "options   root=PARTUUID=$(blkid -s PARTUUID -o value $ROOT) rw" >> /boot/loader/entries/arch.conf
    } else {
        colorread yellow "Looks like your PC doesn't suppot UEFI or not in UEFI mode, ENTER to use grub. Input q to quit:" TMP
        if [[ -z $TMP ]] { install_grub } else { exit }
    }
}

add_user(){
    colorread yellow "Input the user name you want to use (must be lower case):" USER
    useradd -m -g wheel $USER
    color yellow "Set the password"
    passwd $USER
    pacman -S --noconfirm sudo
    sed -i 's/\# \%wheel ALL=(ALL) ALL/\%wheel ALL=(ALL) ALL/g' /etc/sudoers
    colorread yellow "Do you want users in wheel ground run sudo without password? y)yes ENTER)no" noPW
    if [[ -n $noPW ]] {
        sed -i 's/\# \%wheel ALL=(ALL) noPASSWD: ALL/\%wheel ALL=(ALL) noPASSWD: ALL/g' /etc/sudoers
    }
}

install_graphic(){
    lspci | grep -e VGA -e 3D
    color yellow "What is your video graphic card?"
    select GPU (Intel NVIDIA "Intel and NVIDIA" AMD) {
        case $GPU {
            (Intel) pacman -S --noconfirm xf86-video-intel -y ;;
            ("Intel and NVIDIA")
                pacman -S --noconfirm bumblebee -y
                systemctl enable bumblebeed
            ;&
            (NVIDIA)
                color yellow "Version of nvidia-driver to install"
                select VER ("GeForce-8 and newer" "GeForce-6/7" "Older") {
                    case $VER {
                        ("GeForce-8 and newer") pacman -S --noconfirm nvidia -y ;;
                        ("GeForce-6/7") ;& ("Older") pacman -S --noconfirm nvidia-304xx -y ;;
                        (*) color red "Error ! Please input the correct num" ;;
                    }
                    break
                }
            ;;
            (AMD) pacman -S --noconfirm xf86-video-ati -y ;;
            (*) color red "Error ! Please input the correct num" ;;
        }
        break
    }
}

install_bluetooth(){
    pacman -S --noconfirm bluez
    systemctl enable bluetooth
    colorread yellow "Install blueman? y)yes ENTER)no" TMP
    if [[ $TMP == "y" ]] { pacman -S --noconfirm blueman }
}

install_app(){
    colorread yellow "Install yaourt from archlinuxcn or use git ? (for Chinese users) y)yes ENTER)no:" TMP
    if [[ $TMP == y ]] {
        sed -i '/archlinuxcn/d' /etc/pacman.conf
        sed -i '/archlinux-cn/d' /etc/pacman.conf
        select SERVER (USTC TUNA 163) {
            case $SERVER {
                (USTC) echo -e "[archlinuxcn]\nServer = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch" >> /etc/pacman.conf ;;
                (TUNA) echo -e "[archlinuxcn]\nServer = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch" >> /etc/pacman.conf ;;
                (163) echo -e "[archlinuxcn]\nServer = http://mirrors.163.com/archlinux-cn/\$arch" >> /etc/pacman.conf ;;
                (*) color red "Error ! Please input the correct num"
            }
            break
        }
        pacman -Sy
        pacman -S --noconfirm archlinuxcn-keyring
        pacman -S --noconfirm yaourt
    } else {
        pacman -S --noconfirm git
        su - $USER -c "cd ~
            git clone https://aur.archlinux.org/package-query.git
            cd package-query&&makepkg -si
            cd ..
            git clone https://aur.archlinux.org/yaourt.git
            cd yaourt&&makepkg -si
            cd ..
            rm -rf package-query yaourt"
    }
    pacman -S --noconfirm networkmanager xorg-server firefox wqy-zenhei
    systemctl enable NetworkManager
    if [[ $GPU == "Intel and NVIDIA" ]] {
        gpasswd -a $USER bumblebee
    }
}

install_desktop(){
    color yellow "Choose the desktop you want to use:"
    select DESKTOP (KDE Gnome Lxde Lxqt Mate Xfce Deepin Budgie Cinnamon) {
        case $DESKTOP {
            (KDE)
                pacman -S plasma kdebase kdeutils kdegraphics kde-l10n-zh_cn sddm
                systemctl enable sddm
            ;;
            (Gnome)
                pacman -S gnome gnome-terminal
                systemctl enable gdm
            ;;
            (Lxde) ;& (Lxqt)
                pacman -S $DESKTOP lightdm lightdm-gtk-greeter
                systemctl enable lightdm
            ;;
            (Mate)
                pacman -S mate mate-extra mate-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
            ;;
            (Xfce)
                pacman -S xfce4 xfce4-goodies xfce4-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
            ;;
            (Deepin)
                pacman -S deepin deepin-extra deepin-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
                sed -i '108s/#greeter-session=example-gtk-gnome/greeter-session=lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
            ;;
            (Budgie)
                pacman -S budgie-desktop gnome-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
            ;;
            (Cinnamon)
                pacman -S cinnamon gnome-terminal lightdm lightdm-gtk-greeter
                systemctl enable lightdm
            ;;
            (*) color red "Error ! Please input the correct num" ;;
        }
        break
    }
}

rm /root/install_zsh.sh
config_base
config_locale
colorread yellow "Use GRUB or Bootctl? y)Bootctl ENTER)GRUB:" TMP
if [[ $TMP == "y" ]] { install_bootctl } else { install_grub }
add_user
install_graphic
colorread yellow "Do you have bluetooth? y)yes ENTER)no:" TMP
if [[ $TMP == "y" ]] { install_bluetooth }
install_app
install_desktop
color yellow "Done, Thanks for using"
