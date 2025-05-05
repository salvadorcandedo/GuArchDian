![](Imgs/Pasted image 20250505195944.png)

**Guarchdian** es un sistema de bastionado y monitoreo de Arch Linux orientado a entornos domésticos . Está diseñado para fortalecer la seguridad del sistema mediante herramientas como `iptables`, `fail2ban`, `knockd`, y `Suricata`, además de facilitar la visualización de eventos a través de una interfaz basada en ELK Stack. Su objetivo es ofrecer una solución ligera, modular y de bajo mantenimiento para proteger redes pequeñas sin requerir hardware especializado ni conocimientos avanzados en ciberseguridad.

## Scripts de instalacion

No pases por el calvario que tuve que pasar para instalarlo! te he preparado unos scripts que te lo automatizan todo! No dejes que se cuelen en tu sistema.

# Guarchdian

**Guarchdian** es un sistema de bastionado y monitoreo de Arch Linux pensado para entornos domésticos o pequeñas oficinas. Usa herramientas como `iptables`, `fail2ban`, `knockd`, `Suricata` y ELK Stack para proteger y visualizar la actividad del sistema. La idea es tener algo modular, seguro y sin complicaciones, sin necesidad de hardware raro ni conocimientos avanzados.

---

## Instalación

1. **Descarga la ISO de Arch Linux** desde [aquí](https://archlinux.org/download/).

### Método 1

1. Bootea el medio en el equipo donde quieras instalar Arch.
2. Si no tienes Git, instálalo con:

```bash
pacman -Sy git
```


Luego clona el repo y ejecuta los scripts:
```bash
git clone https://github.com/salvadorcandedo/Guarchdian.git
cd instalacion/
chmod +x *.sh
./install.sh
```
---



## ¿Qué hace esto?

Este proyecto automatiza la instalación de Arch con un enfoque en seguridad. Algunas de las cosas que hace:

### 🔐 Cifrado de disco completo

- LVM sobre LUKS, incluso la partición `/boot`
    
- Algoritmos fuertes (AES-512, SHA512)
    
- Llave aleatoria para desbloquear
    

### 🛡️ Secure Boot y GRUB

- GRUB protegido con contraseña
    
- Parámetros seguros al kernel
    

### 🧱 Políticas de contraseñas y bloqueo

- Reglas estrictas de complejidad y expiración
    
- Cuentas se bloquean tras varios intentos fallidos
    

### 🔥 Firewall y SSH

- `iptables` con reglas por defecto estrictas
    
- Limitación de conexiones SSH
    
- Port knocking opcional con `knockd`
    

### 🔍 Monitoreo y auditoría

- `auditd`, `fail2ban`, `sysstat`, `arpwatch`
    
- Antivirus (`clamav`) y detección de rootkits (`rkhunter`)
    
- Alertas visuales con ELK Stack
    

### 🧬 Kernel y servicios

- Parcheo de microcódigo (Intel/AMD)
    
- Desactivación de módulos y protocolos innecesarios
    
- `chrony` y `ntpd` para mantener hora exacta
    

### 🔒 Endurecimiento del sistema

- Permisos ajustados en archivos sensibles
    
- UMASK por defecto a 027
    
- Bloqueo de compiladores para usuarios normales
    
- Escaneo de vulnerabilidades con `arch-audit`

- ## Objetivo

Esto es para quienes quieren un Arch Linux bien asegurado sin tener que hacerlo todo a mano. Ideal para uso personal, home-lab o pequeñas oficinas.
    

---


## Dotfiles

En los dotfiles encontramos scripts de atomatizacion para el hardening de `sysctl` y `sshd_config` además de unos scripts para mandar notificaciones a un servidor de ntfy.
