#!/bin/bash

METHOD="CURL"
HELP="NO"
VERSION="NO"
DIR="kernel-updater"


# Parses arguments 
for arg in "$@"
do
    case $arg in
        -v)
            VERSION="YES"
            ;;
        -h)
            HELP="YES"
            ;;
        -g)
            METHOD="GIT"
            ;;
         *)
           echo Invalid flag/option
           exit 1
    esac
done

# Displays usage with options/flags and exits
if [ $HELP = "YES" ]
then
    echo "Usage: ./kernel-updater.sh [-options]"
    echo "Where options include:"
    echo "-v: Scrapes Kernel.org for latest linux kernel and echos it but does not perform installation"
    echo "-h: Displays Usage with options"
    echo "-g: Downloads Kernel using git instead of the default wget"
    exit 0
fi

# Scrapes Kernel.org for latest stable version of the linux kernel
VER=$(curl -s https://www.kernel.org | grep -A1 latest_link | tail -n1 | egrep -o '>[^<]+' | egrep -o '[^>]+')

# Displayes Latest Stable Version of Linux Kernel and exits
if [ $VERSION = "YES" ]
then
    echo "Latest Stable Linux Version: $VER"
    exit 0
fi

# Updates System and downloads necessary dependencies
yes "yes" | sudo dnf update
yes "yes" | sudo yum group install "Development Tools"
yes "yes" | sudo yum install ncurses-devel bison flex elfutils-libelf-devel openssl-devel
yes "yes" | sudo yum install python3
yes "yes" | sudo yum install bc

# Removes any folder with the same name as dir (kernel-updater)
sudo rm -rf $DIR
# Creates Directory where current stable linux kernel will be downloaded
mkdir -p $DIR
cd $DIR

# Downloads latest stable linux kernel from kernel.org
if [ $METHOD = "WGET" ]
then
    # Using wget
    yes "yes" | sudo yum install wget
    wget=$(wget --output-document - --quiet https://www.kernel.org/ | grep -A 1 "latest_link")
    wget=${wget##*<a href=\"}
    wget=${wget%\">*}
    wget $wget
    unxz -v "linux-$VER.tar.xz"
    tar xvf "linux-$VER.tar"
    cd "linux-$VER"
else  
    # Using git
    yes "yes" | sudo yum install git
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux-2.6.git
    cd "linux-2.6"
    git pull
fi

# Preparatory stage
cp -v /boot/config-$(uname -r) .config
sed -i 's/CONFIG_MODULE_SIG_KEY/#/' .config
sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS/#/' .config
sudo rm /etc/dracut.conf.d/xen.conf

# Creates swap memory necessary for installation
sudo dd if=/dev/zero of=/swapfile bs=1024 count=1048576
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Installs the latest stable linux kernel and reboots the system
yes "" | sudo make -j $(nproc)
sudo make modules_install
sudo make install
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo grubby --set-default /boot/vmlinuz-$VER
sudo swapoff -v /swapfile
sudo rm /swapfile
sudo reboot

exit 0
