#!/bin/bash

# Script para instalar Arch con LVM2 en LUKS y UEFI
# Hecho por [Tu nombre]

set -euo pipefail

# --- Comprobaciones ---
if [ "$(id -u)" != "0" ]; then
   echo "Este script debe ejecutarse como root." >&2
   exit 1
fi

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo "UEFI no soportado." >&2
  exit 1
fi

# Funciones auxiliares
ask_for_disk() {
    local disk
    while true; do
        read -p "Selecciona el disco destino (ej. sda, nvme0n1): " disk
        if [[ -b "/dev/$disk" ]]; then
            echo "$disk"
            return 0
        else
            echo "Disco no válido. Intenta nuevamente." >&2
        fi
    done
}

ask_for_numeric() {
    local prompt_msg="$1"
    local input_val
    while true; do
        read -p "$prompt_msg " input_val
        if [[ "$input_val" =~ ^[0-9]+$ ]]; then
            echo "$input_val"
            return 0
        else
            echo "Entrada inválida. Intenta nuevamente." >&2
        fi
    done
}

ask_for_username() {
    local username
    while true; do
        read -p "Introduce el nombre de usuario: " username
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            echo "$username"
            return 0
        else
            echo "Nombre de usuario inválido. Intenta nuevamente." >&2
        fi
    done
}

ask_for_hostname() {
    local hostname
    while true; do
        read -p "Introduce el nombre del host: " hostname
        if [[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*$ ]]; then
            echo "$hostname"
            return 0
        else
            echo "Nombre de host inválido. Intenta nuevamente." >&2
        fi
    done
}

ask_yes_no() {
    local prompt_msg="$1"
    local choice
    while true; do
        read -p "$prompt_msg (y/n): " choice
        case "$choice" in
            [Yy]) echo "y"; return 0 ;;
            [Nn]) echo "n"; return 0 ;;
            *) echo "Respuesta inválida. Ingresa 'y' o 'n'." >&2 ;;
        esac
    done
}

ask_luks_password_until_success() {
    local partition="$1"
    local crypt_name="$2"
    while true; do
        if cryptsetup -v luksOpen "$partition" "$crypt_name"; then
            cryptsetup -v luksClose "$crypt_name"
            break
        else
            echo "Contraseña incorrecta. Intenta nuevamente." >&2
        fi
    done
}

# --- Obtener datos del usuario ---
echo "Discos disponibles en el sistema:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep "disk"
TARGET_DISK=$(ask_for_disk)

SIZE_OF_SWAP=$(ask_for_numeric "Tamaño de la partición swap en GB:")
SIZE_OF_ROOT=$(ask_for_numeric "Tamaño de la partición raíz / en GB:")

CREATE_VAR_PART=$(ask_yes_no "¿Crear partición separada para /var?")
if [[ "$CREATE_VAR_PART" == "y" ]]; then
    SIZE_OF_VAR=$(ask_for_numeric "Tamaño de la partición /var en GB:")
    VAR_SIZE="${SIZE_OF_VAR}G"
fi

USERNAME=$(ask_for_username)
HOSTNAME=$(ask_for_hostname)

# Variables para el proceso
SWAP_SIZE="${SIZE_OF_SWAP}G"
ROOT_SIZE="${SIZE_OF_ROOT}G"
CRYPT_NAME='crypt_lvm'
LVM_NAME='lvm_arch'
LUKS_KEYS='/etc/luksKeys'

# --- Configuración de particiones y LUKS ---
DISK="/dev/$TARGET_DISK"
if [[ "$DISK" =~ [0-9]$ ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

PARTITION1="${DISK}${PART_SUFFIX}1"  # BIOS boot
PARTITION2="${DISK}${PART_SUFFIX}2"  # EFI
PARTITION3="${DISK}${PART_SUFFIX}3"  # LUKS

sgdisk -og "$DISK"
sgdisk -n 1:2048:4095 -t 1:ef02 -c 1:"BIOS boot" "$DISK"
sgdisk -n 2:4096:1130495 -t 2:ef00 -c 2:"EFI" "$DISK"
sgdisk -n 3:1130496:$(sgdisk -E "$DISK") -t 3:8309 -c 3:"Linux LUKS" "$DISK"

partprobe "$DISK"

cryptsetup -q --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 3000 --use-random --type luks1 luksFormat "$PARTITION3"
ask_luks_password_until_success "$PARTITION3" "$CRYPT_NAME"

dd if=/dev/urandom of=./boot.key bs=2048 count=1
cryptsetup -v luksAddKey -i 1 "$PARTITION3" ./boot.key
cryptsetup -v luksOpen "$PARTITION3" "$CRYPT_NAME" --key-file ./boot.key

# --- Configuración de LVM ---
pvcreate --verbose "/dev/mapper/$CRYPT_NAME"
vgcreate --verbose "$LVM_NAME" "/dev/mapper/$CRYPT_NAME"

lvcreate --verbose -L "$ROOT_SIZE" "$LVM_NAME" -n root
lvcreate --verbose -L "$SWAP_SIZE" "$LVM_NAME" -n swap

if [[ -n "$VAR_SIZE" ]]; then
  lvcreate --verbose -L "$VAR_SIZE" "$LVM_NAME" -n var
  lvcreate --verbose -l 100%FREE "$LVM_NAME" -n home
else
  lvcreate --verbose -l 100%FREE "$LVM_NAME" -n home
fi

# --- Formatear y montar ---
mkfs.ext4 "/dev/mapper/${LVM_NAME}-root"
mkfs.ext4 "/dev/mapper/${LVM_NAME}-home"
mkswap "/dev/mapper/${LVM_NAME}-swap"
swapon "/dev/mapper/${LVM_NAME}-swap"

if [[ -n "$VAR_SIZE" ]]; then
  mkfs.ext4 "/dev/mapper/${LVM_NAME}-var"
fi

mount "/dev/mapper/${LVM_NAME}-root" /mnt
mkdir -p /mnt/home
mount "/dev/mapper/${LVM_NAME}-home" /mnt/home

if [[ -n "$VAR_SIZE" ]]; then
  mkdir -p /mnt/var
  mount "/dev/mapper/${LVM_NAME}-var" /mnt/var
fi

mkdir -p /mnt/tmp

mkfs.vfat -F32 "$PARTITION2"
mkdir -p /mnt/efi
mount "$PARTITION2" /mnt/efi

# --- Instalación base ---
pacman -Sy archlinux-keyring --noconfirm
pacstrap /mnt base base-devel archlinux-keyring linux linux-headers dialog linux-firmware zsh lvm2 mtools networkmanager iwd dhcpcd wget curl git

genfstab -pU /mnt >> /mnt/etc/fstab
mkdir -p "/mnt$LUKS_KEYS"
cp ./boot.key "/mnt$LUKS_KEYS/boot.key"
shred -u ./boot.key

echo "tmpfs /tmp tmpfs rw,nosuid,nodev,noexec,relatime,size=2G 0 0" >> /mnt/etc/fstab
echo "proc /proc proc nosuid,nodev,noexec,hidepid=2,gid=proc 0 0" >> /mnt/etc/fstab

mkdir -p /mnt/etc/systemd/system/systemd-logind.service.d
cat <<EOF > /mnt/etc/systemd/system/systemd-logind.service.d/hidepid.conf
[Service]
SupplementaryGroups=proc
EOF

# Preparar el script chroot
sed -i "s|^DISK=.*|DISK='${DISK}'|g" ./chroot.sh
sed -i "s|^USERNAME=.*|USERNAME='${USERNAME}'|g" ./chroot.sh
sed -i "s|^HOSTNAME=.*|HOSTNAME='${HOSTNAME}'|g" ./chroot.sh

cp ./chroot.sh /mnt
chmod +x /mnt/chroot.sh

# --- Chroot ---
arch-chroot /mnt /bin/bash ./chroot.sh
