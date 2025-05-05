#!/usr/bin/env bash

set -euo pipefail

# Variables
BBlue='\033[1;34m'
NC='\033[0m'

# Verificar ejecución como root
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script debe ejecutarse como root" >&2
  exit 1
fi

# Valores a reemplazar por archinstall.sh
DISK="${_INSTALL_DISK}"
LVM_NAME="lvm_arch"
USERNAME="${_INSTALL_USER}"
HOSTNAME="${_INSTALL_HOST}"
TIMEZONE="Europe/Zurich"
LOCALE="en_US.UTF-8"
LUKS_KEYS='/etc/luksKeys/boot.key'
SSH_PORT=22

# Configuración básica del sistema
pacman-key --init
pacman-key --populate archlinux
userdel -r games 2>/dev/null || true
groupdel games 2>/dev/null || true
timedatectl set-timezone "$TIMEZONE"
hwclock --systohc --utc
sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
export LANG="$LOCALE"
echo 'KEYMAP=de_CH-latin1' > /etc/vconsole.conf
echo 'FONT=lat9w-16' >> /etc/vconsole.conf
echo 'FONT_MAP=8859-1_to_uni' >> /etc/vconsole.conf

# Configuración de red
echo "Configurando systemd-resolved con Stubby..."
pacman -S dnssec-anchors --noconfirm
pacman -S stubby --noconfirm
cat <<EOF > /etc/stubby/stubby.yml
resolution_type: GETDNS_RESOLUTION_STUB
dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: GETDNS_AUTHENTICATION_REQUIRED
dnssec_return_status: GETDNS_EXTENSION_TRUE
appdata_dir: "/var/cache/stubby"
listen_addresses:
  - 127.0.0.1@5353
  - 0::1@5353
upstream_recursive_servers:
  - address_data: 8.8.8.8
    tls_auth_name: "dns.google"
    tls_port: 853
EOF
systemctl enable stubby
systemctl enable systemd-resolved.service

# Configuración de zona horaria
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc --utc

# Configuración de locale
sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
export LANG="$LOCALE"

# Configuración de teclado y fuentes
echo 'KEYMAP=de_CH-latin1' > /etc/vconsole.conf
echo 'FONT=lat9w-16' >> /etc/vconsole.conf
echo 'FONT_MAP=8859-1_to_uni' >> /etc/vconsole.conf

# Configuración de iptables
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -m limit --limit 2/min --limit-burst 5 -j ACCEPT
iptables -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -j DROP
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables-save > /etc/iptables/rules.v4

# Configuración de logrotate
pacman -S --noconfirm logrotate
cat <<EOF > /etc/logrotate.d/custom
/var/log/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
EOF

# Configuración de generadores de entropía
pacman -S --noconfirm rng-tools
systemctl enable rngd
pacman -S --noconfirm haveged
systemctl enable haveged.service

# Instalación de herramientas de seguridad
pacman -S --noconfirm arch-audit pax-utils lynis

# Configuración de ClamAV
pacman -S --noconfirm clamav
if [ ! -f /etc/clamav/freshclam.conf ]; then
  clamconf -g freshclam.conf > freshclam.conf
  mv freshclam.conf /etc/clamav/freshclam.conf
fi

# Función auxiliar para configurar opciones de clamd
ensure_clamd_option() {
  local KEY="$1"
  local VALUE="$2"
  if grep -Eq "^#?\s*${KEY}\s" "$CLAMD_CONF"; then
    sed -i "s|^#\?\s*${KEY}.*|${KEY} ${VALUE}|" "$CLAMD_CONF"
  else
    echo "${KEY} ${VALUE}" >> "$CLAMD_CONF"
  fi
}

# Configuración de permisos para logs
mkdir -p /var/log/clamav
touch /var/log/clamav/freshclam.log
chmod 600 /var/log/clamav/freshclam.log
chown clamav:clamav /var/log/clamav/freshclam.log

# Servicios de actualización y escaneo
systemctl enable clamav-freshclam.service
systemctl enable clamav-daemon.service

# Instalación de herramientas adicionales
pacman -S --noconfirm rkhunter arpwatch usbguard
sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
systemctl enable usbguard.service

# Configuración de seguridad en login.defs
sed -i 's/^UMASK[[:space:]]\+022/UMASK\t\t027/' /etc/login.defs
sed -i '/#SHA_CRYPT_MIN_ROUNDS 5000/s/^#//;/#SHA_CRYPT_MAX_ROUNDS 5000/s/^#//' /etc/login.defs
sed -i 's/^FAIL_DELAY[[:space:]]\+3/FAIL_DELAY\t\t5/' /etc/login.defs
sed -i 's/^LOGIN_RETRIES[[:space:]]\+5/LOGIN_RETRIES\t\t3/' /etc/login.defs
sed -i 's/^LOGIN_TIMEOUT[[:space:]]\+60/LOGIN_TIMEOUT\t\t30/' /etc/login.defs
sed -i 's/^ENCRYPT_METHOD[[:space:]]\+.*$/ENCRYPT_METHOD YESCRYPT/' /etc/login.defs
sed -i 's/^#YESCRYPT_COST_FACTOR[[:space:]]\+.*$/YESCRYPT_COST_FACTOR 7/' /etc/login.defs
sed -i 's/^#MAX_MEMBERS_PER_GROUP[[:space:]]\+0/MAX_MEMBERS_PER_GROUP\t100/' /etc/login.defs
sed -i 's/^#HMAC_CRYPTO_ALGO[[:space:]]\+.*$/HMAC_CRYPTO_ALGO SHA512/' /etc/login.defs
sed -i '/^PASS_MAX_DAYS/c\PASS_MAX_DAYS 730' /etc/login.defs
sed -i '/^PASS_MIN_DAYS/c\PASS_MIN_DAYS 2' /etc/login.defs

# Configuración de PAM para intentos fallidos
echo "auth required pam_tally2.so onerr=fail audit silent deny=5 unlock_time=900" >> /etc/pam.d/common-auth

# Configuración adicional de permisos
echo "umask 027" | sudo tee -a /etc/profile
echo "umask 027" | sudo tee -a /etc/bash.bashrc

# Desactivación de protocolos no deseados
echo "install dccp /bin/true" >> /etc/modprobe.d/disable-protocols.conf
echo "install sctp /bin/true" >> /etc/modprobe.d/disable-protocols.conf
echo "install rds /bin/true" >> /etc/modprobe.d/disable-protocols.conf
echo "install tipc /bin/true" >> /etc/modprobe.d/disable-protocols.conf

# Desactivación de core dump
echo "* hard core 0" >> /etc/security/limits.conf

# Configuración de NTP
pacman -S --noconfirm chrony ntp
systemctl enable chronyd
systemctl enable ntpd

# Configuración de monitoreo
pacman -S --noconfirm sysstat
systemctl enable sysstat

# Configuración de auditoría
pacman -S --noconfirm audit
wget -O "$LOCAL_RULES_FILE" "$RULES_URL"
systemctl restart auditd
systemctl enable auditd

# Servicios esenciales
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable dhcpcd.service

# Configuración de Fail2ban
pacman -S --noconfirm fail2ban
cat <<EOF > /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port    = "$SSH_PORT"
logpath = %(sshd_log)s
maxretry = 5
EOF
systemctl enable fail2ban

# Configuración de journald
cat <<EOF > /etc/systemd/journald.conf
[Journal]
Storage=persistent
Compress=yes
Seal=yes
SplitMode=login
ForwardToSyslog=no
SystemMaxUse=200M
EOF
systemctl restart systemd-journald

# Configuración de sudo
groupadd sudo
echo "Defaults secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" > /etc/sudoers
echo "Defaults !rootpw" >> /etc/sudoers
echo "Defaults umask=077" >> /etc/sudoers
echo "Defaults editor=/usr/bin/vim" >> /etc/sudoers
echo "Defaults env_reset" >> /etc/sudoers
echo "Defaults env_reset,env_keep=\"COLORS DISPLAY HOSTNAME HISTSIZE INPUTRC KDEDIR LS_COLORS\"" >> /etc/sudoers
echo "Defaults env_keep += \"MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE\"" >> /etc/sudoers
echo "Defaults env_keep += \"LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES\"" >> /etc/sudoers
echo "Defaults env_keep += \"LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE\"" >> /etc/sudoers
echo "Defaults env_keep += \"LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY\"" >> /etc/sudoers
echo "Defaults timestamp_timeout=30" >> /etc/sudoers
echo "Defaults !visiblepw" >> /etc/sudoers
echo "Defaults always_set_home" >> /etc/sudoers
echo "Defaults match_group_by_gid" >> /etc/sudoers
echo "Defaults always_query_group_plugin" >> /etc/sudoers
echo "Defaults passwd_timeout=10" >> /etc/sudoers
echo "Defaults passwd_tries=3" >> /etc/sudoers
echo "Defaults loglinelen=0" >> /etc/sudoers
echo "Defaults insults" >> /etc/sudoers
echo "Defaults lecture=once" >> /etc/sudoers
echo "Defaults requiretty" >> /etc/sudoers
echo "Defaults logfile=/var/log/sudo.log" >> /etc/sudoers
echo "Defaults log_input, log_output" >> /etc/sudoers
echo "%sudo ALL=(ALL) ALL" >> /etc/sudoers
echo "@includedir /etc/sudoers.d" >> /etc/sudoers
chmod 440 /etc/sudoers
chown root:root /etc/sudoers

# Configuración de arch-audit
pacman -S --noconfirm arch-audit
cat <<EOF > /usr/local/bin/arch-audit-check
#!/bin/bash
arch-audit | tee /var/log/arch-audit.log
EOF
chmod +x /usr/local/bin/arch-audit-check

# Servicio y temporizador para arch-audit
cat <<EOF > /etc/systemd/system/arch-audit.service
[Unit]
Description=Servicio Arch Audit
[Service]
Type=oneshot
ExecStart=/usr/local/bin/arch-audit-check
EOF

cat <<EOF > /etc/systemd/system/arch-audit.timer
[Unit]
Description=Ejecutar arch-audit diariamente
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
EOF

systemctl enable arch-audit.timer
systemctl start arch-audit.timer

# Creación de usuario
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -m -G sudo,wheel,uucp -s /bin/zsh "$USERNAME"
  chown "$USERNAME:$USERNAME" /home/"$USERNAME"
fi

# Configuración de nano
echo "set backup" >> /home/"$USERNAME"/.nanorc
echo "set backupdir \"~/.cache/nano/backups/\"" >> /home/"$USERNAME"/.nanorc
chmod 600 /home/"$USERNAME"/.nanorc

# Establecer contraseñas
while true; do
  passwd "$USERNAME"
  if [ $? -eq 0 ]; then break; fi
done

while true; do
  passwd root
  if [ $? -eq 0 ]; then break; fi
done

# Descargar configuración de nano
curl -sL https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | sh -s -- -y

# Ajustes de seguridad en nano
echo "set constantshow" >> /home/"$USERNAME"/.nanorc
echo "set locking" >> /home/"$USERNAME"/.nanorc
echo "set nohelp" >> /home/"$USERNAME"/.nanorc
echo "set nonewlines" >> /home/"$USERNAME"/.nanorc
echo "set nowrap" >> /home/"$USERNAME"/.nanorc
echo "set minibar" >> /home/"$USERNAME"/.nanorc
echo "set zap" >> /home/"$USERNAME"/.nanorc
echo "set linenumbers" >> /home/"$USERNAME"/.nanorc
echo "set tabsize 4" >> /home/"$USERNAME"/.nanorc
echo "set tabstospaces" >> /home/"$USERNAME"/.nanorc
echo "set wordbounds punct,alnum" >> /home/"$USERNAME"/.nanorc
echo "set regexp ^[A-Za-z_][A-Za-z0-9_]*$" >> /home/"$USERNAME"/.nanorc

# Configuración de SSH
configure_ssh() {
  mkdir -p "/home/$USERNAME/.ssh"
  if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -t "$SSH_KEY_TYPE" -C "$USERNAME@$HOSTNAME" -f "$SSH_KEY_FILE" -q -N ""
  fi

  if [ -f "$SSH_CONFIG_FILE" ] && [ ! -f "$SSH_CONFIG_FILE.bak" ]; then
    cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE.bak"
  fi

  install -Dm644 /dev/stdin "$SSH_CONFIG_FILE" <<EOF
 Host "$HOSTNAME"
  HostName "$HOSTNAME"
  Port "$SSH_PORT"
  User "$USERNAME"
  IdentityFile "$SSH_KEY_FILE"
  HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
  KexAlgorithms curve2559-sha256@libssh.org,curve25519-sha256,diffie-hellman-group18-sha512,d
