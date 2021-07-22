#!/usr/bin/env bash
## CONFIGURE THESE VARIABLES
## ALSO LOOK AT THE install_packages FUNCTION TO SEE WHAT IS ACTUALLY INSTALLED

# Keymap
KEYMAP='us'

# Choose your video driver
# For Intel
VIDEO_DRIVER="i915"
# For nVidia
#VIDEO_DRIVER="nouveau"
# For ATI
#VIDEO_DRIVER="radeon"
# For generic stuff
#VIDEO_DRIVER="vesa"

setup() {
	
    echo 'Installing base system'
    install_base
    
    echo 'Setting fstab'
    set_fstab 

    echo 'Chrooting into installed system to continue setup...'
    cp $0 /mnt/setup.sh
    arch-chroot /mnt ./setup.sh chroot

    if [ -f /mnt/setup.sh ]
    then
        echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
        echo 'Make sure you unmount everything before you try to run this script again.'
    else
        echo 'Unmounting filesystems'
        unmount_filesystems
        echo 'Done! Reboot system.'
    fi
}

configure() {
    echo 'Setting hostname'
    set_hostname 

    echo 'Setting timezone'
    set_timezone 

    echo 'Setting console keymap'
    set_keymap

    echo 'Setting root password'
    set_root_password 

    echo 'Creating initial user'
    create_user 

    echo 'Configuring sudo'
    set_sudoers
    
    echo 'Installing additional packages'
    install_packages
    
    echo 'configuring grub'
    set_grub
    
    echo 'Clearing package tarballs'
    clean_packages

    rm /setup.sh
}

install_base() {
    pacstrap /mnt base linux linux-firmware nano
}

set_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

set_hostname() {
	read -p "Enter your hostname :" hostname
    echo "$hostname" > /etc/hostname
    
    echo "Set hosts file.."
    cat >> /etc/hosts <<EOF
127.0.0.1	localhost 
::1		localhost
127.0.1.1	$hostname.localdomain	$hostname 
EOF
}

set_timezone() {
    read -p "Timezone? :" TIMEZONE 
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc
}

set_locale() {
    echo 'LANG="en_US.UTF-8"' >> /etc/locale.conf
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
}

set_keymap() {
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
}

set_root_password() {
    read -sp "Enter the password for root :" passroot
    echo -en "$passroot\n$passroot" | passwd
}

create_user() {
	read -p "Enter a name for new user :" name
    useradd -m -G wheel "$name"
 
    read -sp "Enter the password for user $name :" passuser
    echo -en "$passuser\n$passuser" | passwd "$name"
}

set_sudoers() {
    EDITOR=nano visudo
}

install_packages() {
    local packages=''

    # Network
    packages+=' dialog networkmanager wireless_tools wpa_supplicant' 
	
	# audio
	packages+=' pulseaudio pulseaudio-alsa pulseaudio-bluetooth alsa-utils bluez bluez-utils'
    
    # Fonts
    packages+=' ttf-dejavu ttf-liberation'
    
    # grub
    packages+=' grub base-devel linux-headers'

    # tools
    packages+=' gvfs gvfs-mtp mtools ntfs-3g dosfstools os-prober'

	# Xserver
	packages+=' xorg-server xorg-xinit i3-gaps xdg-user-dirs rxvt-unicode'

    if [ "$VIDEO_DRIVER" = "i915" ]
    then
        packages+=' xf86-video-intel libva-intel-driver intel-ucode'
    elif [ "$VIDEO_DRIVER" = "nouveau" ]
    then
        packages+=' xf86-video-nouveau'
    elif [ "$VIDEO_DRIVER" = "radeon" ]
    then
        packages+=' xf86-video-ati'
    elif [ "$VIDEO_DRIVER" = "vesa" ]
    then
        packages+=' xf86-video-vesa'
    fi

    pacman -Sy --noconfirm $packages
}

set_grub() {
	grub-install --target =i386-pc /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
}

clean_packages() {
    yes | pacman -Scc
}

unmount_filesystems() {
	umount -a
}

set -ex

if [ "$1" == "chroot" ]
then
    configure
else
    setup
fi

