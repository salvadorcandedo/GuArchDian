#!/usr/bin/env bash
# ================================================================
# Secure Boot Setup Script
# Description: Configura UEFI Secure Boot en un sistema Arch,
#              generando e inscribiendo las claves PK/KEK/db/dbx,
#              y firmando los binarios EFI.
# Autor: [Tu nombre]
# Uso: sudo ./secureboot_setup.sh [-d KEY_DIR] [-p EFI_MOUNT] [-k KEY_SIZE]
#                                  [-v VALID_DAYS] [-o] [-h]
# ================================================================

set -euo pipefail
IFS=$'\n\t'

# Valores por defecto
KEY_DIR="/etc/efi-keys"
EFI_MOUNT="/boot/efi"
KEY_SIZE=2048
VALID_DAYS=3650
UPDATE_ONLY=false
LOGFILE="/var/log/secureboot_setup.log"

# Colores para la salida
readonly C_OK="\033[1;32m"
readonly C_INFO="\033[1;34m"
readonly C_ERR="\033[1;31m"
readonly C_NC="\033[0m"

# Funciones para mostrar logs
echo_log() { printf "%b %s\n" "${C_INFO}" "${1}" | tee -a "$LOGFILE"; }
echo_err() { printf "%b %s\n" "${C_ERR}" "${1}" | tee -a "$LOGFILE"; exit 1; }

# Muestra el uso del script
usage() {
  cat <<EOF
Uso: sudo $0 [opciones]
  -d KEY_DIR     Directorio para almacenar claves y listas (default: $KEY_DIR)
  -p EFI_MOUNT   Partición EFI montada (default: $EFI_MOUNT)
  -k KEY_SIZE    Tamaño de la clave RSA (default: $KEY_SIZE)
  -v VALID_DAYS  Validez del certificado en días (default: $VALID_DAYS)
  -o             Solo actualización: inscribir archivos .esl/.auth existentes
  -h             Mostrar ayuda y salir
EOF
  exit 1
}

# Parsear opciones
while getopts ":d:p:k:v:oh" opt; do
  case "$opt" in
    d) KEY_DIR="$OPTARG" ;;  
    p) EFI_MOUNT="$OPTARG" ;;  
    k) KEY_SIZE="$OPTARG" ;;  
    v) VALID_DAYS="$OPTARG" ;;  
    o) UPDATE_ONLY=true ;;  
    h) usage ;;              
    :) echo_err "La opción -$OPTARG requiere un argumento." ;;  
    \?) echo_err "Opción inválida: -$OPTARG" ;;  
  esac
done

# Verificar que se ejecute como root
[[ $(id -u) -eq 0 ]] || echo_err "Debe ejecutarse como root"

# Verificar si está en UEFI
[[ -d /sys/firmware/efi/efivars ]] || echo_err "UEFI no detectado. Secure Boot requiere UEFI."

# Verificar dependencias
for cmd in openssl efibootmgr sbsigntools efi-updatevar cert-to-efi-sig-list sign-efi-sig-list uuidgen; do
  command -v "$cmd" >/dev/null || echo_err "Falta dependencia: $cmd"
done

# Preparar el entorno
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
echo_log "Usando directorio de claves: $KEY_DIR"
echo_log "Montaje de la partición EFI: $EFI_MOUNT"

# Nombres de archivos de claves
declare -A CERT=( [PK]=PK [KEK]=KEK [db]=db [dbx]=dbx )

cd "$KEY_DIR"

# Generar claves y certificados si no es solo actualización
if ! $UPDATE_ONLY; then
  echo_log "Generando claves y certificados (tamaño=$KEY_SIZE, validez=$VALID_DAYS días)"
  for name in PK KEK db dbx; do
    openssl req -newkey rsa:"$KEY_SIZE" -nodes \
      -keyout ${name}.key -x509 -sha256 -days "$VALID_DAYS" \
      -subj "/CN=Secure Boot ${name} Certificate/" \
      -out ${name}.crt
    openssl x509 -in ${name}.crt -outform DER -out ${name}.cer
  done

  # Hacer copia de seguridad de las variables EFI existentes
  echo_log "Respaldo de variables EFI existentes"
  for var in PK KEK db dbx; do
    if efivar --list | grep -qi "^${var}-"; then
      efivars_dir=/sys/firmware/efi/efivars
      cp "$efivars_dir/${var}-*.efi" "${name}_old_${var}.esl" || true
    fi
  done

  # Crear listas .esl y .auth
  echo_log "Creando listas de firmas EFI"
  for var in PK KEK db dbx; do
    uuid="$(uuidgen)"
    cert-to-efi-sig-list -g "$uuid" ${var}.cer ${var}.esl
    sign-efi-sig-list -k PK.key -c PK.crt "$var" ${var}.esl ${var}.auth
    # KEK firma las listas posteriores
    if [[ $var == "db" || $var == "dbx" ]]; then
      sign-efi-sig-list -k KEK.key -c KEK.crt "$var" ${var}.esl ${var}.auth
    fi
  done
else
  echo_log "Solo actualización: saltando la generación de claves"
fi

# Inscribir las claves
echo_log "Inscribiendo las variables de Secure Boot"
for var in PK KEK db dbx; do
  if [[ -f ${var}.auth ]]; then
    efi-updatevar -e -f ${var}.auth "$var"
    echo_log "Inscrito $var"
  else
    echo_err "Falta ${var}.auth – no se puede inscribir $var"
  fi
done

# Firmar el binario GRUB
GRUB_EFI="${EFI_MOUNT}/EFI/arch/grubx64.efi"
if [[ -f "$GRUB_EFI" ]]; then
  echo_log "Firmando binario GRUB: $GRUB_EFI"
  sbsign --key db.key --cert db.crt --output "$GRUB_EFI" "$GRUB_EFI"
else
  echo_err "No se encontró GRUB EFI en $GRUB_EFI"
fi

# Verificar la inscripción
echo_log "Verificando las variables de Secure Boot"
efibootmgr -v || echo_log "Error al listar entradas de arranque EFI"

echo_log "Configuración de Secure Boot completa. Reinicie para activar."
