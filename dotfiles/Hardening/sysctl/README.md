# Hardening de sysctl

Este script aplica configuraciones de seguridad y rendimiento a través de `sysctl`, utilizando el archivo persistente `/etc/sysctl.d/99-sysctl.conf`. Está diseñado para fortalecer el sistema operativo Linux frente a ataques comunes, mejorar el aislamiento de procesos y ajustar parámetros de red.

## Qué hace este script

### Seguridad del sistema

- Desactiva funciones potencialmente peligrosas como:
  - clonación de espacios de nombres no privilegiados (`userns_clone`)
  - uso de `userfaultfd` por usuarios sin privilegios
  - acceso a logs del kernel (`dmesg`) sin permisos
  - uso de `ptrace` para procesos no relacionados
  - carga de módulos del kernel en tiempo de ejecución (opcional)

- Refuerza mecanismos de mitigación de vulnerabilidades:
  - aleatorización de direcciones de memoria (ASLR)
  - protección de enlaces simbólicos y enlaces duros
  - restricción de volcados de memoria (core dumps)
  - ocultación de punteros del kernel y estructuras internas

### Seguridad de red

- Desactiva comportamientos peligrosos por defecto:
  - redirecciones ICMP y source routing
  - anuncios de router IPv6 y autoconfiguración
  - envío y recepción de paquetes broadcast y bogus ICMP

- Mejora la robustez ante ataques de red:
  - activa SYN cookies para mitigar SYN flood
  - activa filtrado de paquetes con direcciones falsificadas (rp_filter)
  - ajusta límites para evitar desbordamientos y DoS en colas TCP y UDP

### Rendimiento de red

- Ajusta buffers de red (`rmem`, `wmem`, `backlog`, `somaxconn`)
- Activa TCP Fast Open y SACK
- Habilita el algoritmo de control de congestión BBR
- Optimiza comportamiento de keepalive y reutilización de sockets

### Otros ajustes del sistema

- Control del uso de memoria y sobrecompromiso (`overcommit_memory`)
- Reducción de `swappiness` y presión sobre el caché VFS
- Configuración de tiempo de espera y manejo de conexiones TCP muertas

## Uso

Ejecutar como root:

```bash
sudo ./sysctl.sh
