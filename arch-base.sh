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
    cat > /etc/sudoers <<EOF
## sudoers file.
##
## This file MUST be edited with the 'visudo' command as root.
## Failure to use 'visudo' may result in syntax or file permission errors
## that prevent sudo from running.
##
## See the sudoers man page for the details on how to write a sudoers file.
##

##
## Host alias specification
##
## Groups of machines. These may include host names (optionally with wildcards),
## IP addresses, network numbers or netgroups.
# Host_Alias	WEBSERVERS = www1, www2, www3

##
## User alias specification
##
## Groups of users.  These may consist of user names, uids, Unix groups,
## or netgroups.
# User_Alias	ADMINS = millert, dowdy, mikef

##
## Cmnd alias specification
##
## Groups of commands.  Often used to group related commands together.
# Cmnd_Alias	PROCESSES = /usr/bin/nice, /bin/kill, /usr/bin/renice, \
# 			    /usr/bin/pkill, /usr/bin/top

##
## Defaults specification
##
## You may wish to keep some of the following environment variables
## when running commands via sudo.
##
## Locale settings
# Defaults env_keep += "LANG LANGUAGE LINGUAS LC_* _XKB_CHARSET"
##
## Run X applications through sudo; HOME is used to find the
## .Xauthority file.  Note that other programs use HOME to find   
## configuration files and this may lead to privilege escalation!
# Defaults env_keep += "HOME"
##
## X11 resource path settings
# Defaults env_keep += "XAPPLRESDIR XFILESEARCHPATH XUSERFILESEARCHPATH"
##
## Desktop path settings
# Defaults env_keep += "QTDIR KDEDIR"
##
## Allow sudo-run commands to inherit the callers' ConsoleKit session
# Defaults env_keep += "XDG_SESSION_COOKIE"
##
## Uncomment to enable special input methods.  Care should be taken as
## this may allow users to subvert the command being run via sudo.
# Defaults env_keep += "XMODIFIERS GTK_IM_MODULE QT_IM_MODULE QT_IM_SWITCHER"
##
## Uncomment to enable logging of a command's output, except for
## sudoreplay and reboot.  Use sudoreplay to play back logged sessions.
# Defaults log_output
# Defaults!/usr/bin/sudoreplay !log_output
# Defaults!/usr/local/bin/sudoreplay !log_output
# Defaults!/sbin/reboot !log_output

##
## Runas alias specification
##

##
## User privilege specification
##
root ALL=(ALL) ALL

## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL) ALL

## Same thing without a password
# %wheel ALL=(ALL) NOPASSWD: ALL

## Uncomment to allow members of group sudo to execute any command
# %sudo ALL=(ALL) ALL

## Uncomment to allow any user to run sudo if they know the password
## of the user they are running the command as (root by default).
# Defaults targetpw  # Ask for the password of the target user
# ALL ALL=(ALL) ALL  # WARNING: only use this together with 'Defaults targetpw'

%rfkill ALL=(ALL) NOPASSWD: /usr/sbin/rfkill
%network ALL=(ALL) NOPASSWD: /usr/bin/netcfg, /usr/bin/wifi-menu

## Read drop-in files from /etc/sudoers.d
## (the '#' here does not indicate a comment)
#includedir /etc/sudoers.d
EOF

    chmod 440 /etc/sudoers
}

install_packages() {
    local packages=''

    # grub
    packages+=' grub base-devel linux-headers'
    
    # Network
    packages+=' dialog networkmanager wireless_tools wpa_supplicant' 
	
	# audio
	# packages+=' pulseaudio pulseaudio-alsa pulseaudio-bluetooth alsa-utils bluez bluez-utils'
    
    # Fonts
    packages+=' ttf-dejavu ttf-liberation'
    
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
	grub-install --target=i386-pc /dev/sda
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

