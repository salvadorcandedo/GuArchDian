# **1. Elección del sistema de virtualización**

## **Opciones principales:**

1. **KVM (Kernel-based Virtual Machine)**
    
    - Es una solución de virtualización de código abierto integrada en el kernel de Linux.
    - **Ventajas** :
        - Altamente seguro y confiable, ya que está profundamente integrado en el kernel de Linux.
        - Compatible con SELinux y AppArmor para mejorar la seguridad.
        - Permite utilizar herramientas como `libvirt` para gestionar las máquinas virtuales.
        - Soporta cifrado de discos y redes virtuales seguras.
    - **Desventajas** :
        - Requiere conocimientos técnicos avanzados para configurarlo y optimizarlo.
        
2. **VirtualBox**
    
    - Una solución de virtualización multiplataforma desarrollada por Oracle.
    - **Ventajas** :
        - Fácil de usar y configurar, ideal para entornos de aprendizaje.
        - Amplia documentación y comunidad de soporte.
    - **Desventajas** :
        - No es tan seguro como KVM, ya que no está diseñado específicamente para entornos críticos.
        - Menor rendimiento en comparación con soluciones nativas como KVM.
3. **Xen**
    
    - Un hipervisor de tipo 1 (bare-metal) que se utiliza en entornos empresariales.
    - **Ventajas** :
        - Diseñado para ser altamente seguro y eficiente.
        - Ideal para proyectos que requieren aislamiento total entre sistemas.
    - **Desventajas** :
        - Complejo de configurar y mantener.
        - Menos documentación disponible en comparación con KVM.
4. **Proxmox VE**
    
    - Una plataforma de virtualización basada en KVM y LXC (contenedores).
    - **Ventajas** :
        - Interfaz gráfica intuitiva para gestionar máquinas virtuales.
        - Soporta VLANs, firewalls integrados y cifrado de red.
    - **Desventajas** :
        - Puede ser excesivo para un proyecto de una maquina virtual.

---

# Sistema de Virtualización 

Para este proyecto, se ha elegido KVM como sistema de virtualización debido a su integración nativa con el kernel de Linux, lo que garantiza un alto nivel de seguridad y rendimiento. Además, KVM permite implementar medidas avanzadas de hardening, como  SElinux y cifrado de disco (LUKS), esenciales para un entorno  bastionado.

## Instalación 

Vamos a configurar KVM en una maquina linux debian pero soporta cualquier distribución siempre que el hardware soporte la virtualizacion, para asegurarnos de ello introduciremos el siguiente comando :

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```
- Si el resultado es `0`, tu CPU no soporta virtualización.
- Si el resultado es mayor a `0`, tu CPU es compatible.

#####  **Instalar KVM y herramientas necesarias**

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
```

### Paquetes

- **qemu-kvm** : El hipervisor KVM.
- **libvirt-daemon-system** : Configuración del sistema para libvirt.
- **libvirt-clients** : Herramientas de línea de comandos para gestionar máquinas virtuales.
- **bridge-utils** : Herramientas para configurar redes puente (bridges). [OPCIONAL]
- **virt-manager** : Interfaz gráfica para gestionar máquinas virtuales.

Para poder gestionar máquinas virtuales sin usar `sudo`, agrega tu usuario a los grupos `libvirt` y `kvm`

```bash
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)
```

Podemos comprobar que estamos dentro de los grupos con un `id`

### **Iniciar y habilitar los servicios de libvirt**

```bash
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
```

Con `enable` habilitamos que el daemon se inicie al iniciarse el sistema

El archivo de systemd que define como se inicia y gestiona el servicio libvirtd esta en la ruta `/usr/lib/systemd/system/libvirtd.service`


Verificamos que el servicio esté funcionando correctamente:

```bash
sudo systemctl status libvirtd
```


---

Para este trabajo vamos a usar la imagen de arch mas reciente:

[archlinux-2025.04.01-x86_64.iso](https://es.mirrors.cicku.me/archlinux/iso/2025.04.01/archlinux-2025.04.01-x86_64.iso)

--- 

## Configuracion de la red

La ruta donde crearemos nuestras redes en KVM se definen en archivos xml en la siguiente ruta :

`etc/libvirt/qemu/networks/`

Tienen la siguiente estructura, por ejemplo para una NAT:
```xml
<network>
  <name>default</name>
  <uuid>d71dcea8-c077-4051-8c84-e8cb13ca7f6e</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:10:8c:c2'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>

```
Podemos verificar el estado de las redes con el comando:
```bash
➜  ~ virsh net-list --all
 Name   State   Autostart   Persistent
----------------------------------------
```

Para crear una NAT por defecto usamos el simple comando:
```bash
sudo virsh net-start default
```
Podemos habilitar que se levante cada vez que iniciamos el sistema:
```bash
sudo virsh net-autostart default
```



Ahora que KVM está instalado, usamos la interfaz gráfica (`virt-manager`) para crear una máquina virtual:

![[Pasted image 20250419231155.png]]

Podemos crear una maquina virtual desde la linea de comandos igualmente 

```bash
➜  ~ virt-install \
--name guarchdian \    
--ram 4096 \
--vcpus 2 \
--disk path=/var/lib/libvirt/images/arch-linux.qcow2,size=50 \
--cdrom /tmp/archlinux-2025.04.01-x86_64.iso \ 
--os-variant archlinux \
--network network=default \
--graphics spice

```
---
#### **Explicación de los parámetros**

1. **`--name arch-linux`**
    
    - Define el nombre de la máquina virtual. 
    
2. **`--ram 4096`**
    
    - Asigna **4096 MB (4 GB)** de memoria RAM a la máquina virtual. 
    
3. **`--vcpus 2`**
    
    - Asigna **2 CPUs virtuales** a la máquina virtual. Esto es suficiente para una instalación básica de Arch Linux.
    
4. **`--disk path=/var/lib/libvirt/images/arch-linux.qcow2,size=50`**
    
    - Crea un disco virtual en formato `qcow2` en la ruta `/var/lib/libvirt/images/arch-linux.qcow2`.
    - El tamaño del disco es de **50 GB** , especificado con `size=50`.
    - El formato `qcow2` es dinámico, lo que significa que el archivo solo ocupará espacio en disco a medida que se utilice.
    
5. **`--cdrom /ruta/a/archlinux.iso`**
    
    - Especifica la ISO de instalación de Arch Linux que se usará para instalar el sistema operativo en la máquina virtual. Reemplaza `/ruta/a/archlinux.iso` con la ubicación real de tu archivo ISO.
    
6. **`--os-variant archlinux`**
    
    - Especifica que el sistema operativo es **Arch Linux** . Esto ayuda a optimizar la configuración de la VM.
    
7. **`--network network=default`**
    
    - Configura la red de la máquina virtual para usar la red NAT predeterminada (`default`)
    
8. **`--graphics spice`**
    
    - Habilita una interfaz gráfica remota usando el protocolo **SPICE** para interactuar con la máquina virtual. Esto te permitirá ver y controlar la VM durante la instalación.

![[Pasted image 20250419234427.png]]
![[Pasted image 20250419234518.png]]
---

# 2 . Instalacion de Arch-Linux

La instalacion de un arch linux siempre es un merito en tu historia como administrador de sistemas, es ya casi un meme el decir "yo uso arch linux", desde luego es una instalacion algo diferente de las que estamos acostumbrados. Realmente ARCH no es tan complicado de instalar si seguimos los pasos detalladamente .

Para seguir una instalacion limpia de arch podemos leer la [wiki](https://wiki.archlinux.org/title/Installation_guide) 
Nosotros vamos a seguir una instalacion algo diferente a la habitual ya que vamos a securizar el sistema encriptando volumenes usando LURKS


Vamos a hacer una linea de objetivos
- Cifrado completo del disco.
- Configuración de políticas de seguridad avanzadas (SELinux, AppArmor).
- Aislamiento de servicios y usuarios.
- Firewall robusto (iptables/nftables).
- Auditoría y monitoreo continuo.
- Uso de herramientas como `fail2ban`, `auditd`, y `osquery`.


## Primeros pasos

### Verificar la conexion a internet

Vamos a lanzar una serie de comandos para verificar que estemos funcionando en la NAT y que tengamos conexion a internet 

![[Pasted image 20250424170341.png]]

Realizamos un ping y vemos que ya contamos con resolucion DNS , el servidor dns es la `127.0.0.53` majejado por systemd-resolved , Ademas observamos que la nat es la `192.168.122.0/24` tal como se indica en el archivo `etc/libvirt/qemu/networks/`

### Teclado y Zona horaria

Establecemos el teclado y la zona horaria. Yo uso `us` porque soy un masoca y ya estoy aconstumbrado

![[Pasted image 20250424170840.png]]

```sh
loadkeys <idioma>
timedatectl set-timezone Europe/Madrid
timedatectl set-ntp true
```

### Particionar y cifrar el disco

`lsblk`
Podemos observar que nuestro disco principal (50 GB) es el `/dev/vda` 
![[Pasted image 20250424170957.png]]
Vamos a proceder a crear las particiones y a cifrarlas;

Vamos a crear una tabla de particiones GPT:

```bash
parted /dev/vda mklabel gpt
```

Tenemos que crear una imagen de arrange (sin cifrar) y otra para el sistema (cifrada)

```bash
parted /dev/vda mkpart primary 1MiB 512MiB
parted /dev/vda set 1 boot on
parted /dev/vda mkpart primary 512MiB 100%
```

![[Pasted image 20250424171838.png]]

Si listamos los discos ahora vemos dos particiones `/vda/vda1` y `/vda/vda2
![[Pasted image 20250424171939.png]]

Ahora formateamos la particion de Arranque
`mkfs.fat -F32 /dev/vda1`
![[Pasted image 20250424172102.png]]

Una vez creada la particion de arranque pasamos a cifrar con LUKS la particion del sistema operativo, esto es muy importante para el bastionado de nuestro sistema 

%% 
Por defecto, LUKS2  (la versión más reciente de LUKS) utiliza los siguientes parámetros: 

    Cifrado : AES-XTS (Advanced Encryption Standard - XTS mode).
        AES  es un estándar ampliamente utilizado y considerado seguro.
        XTS  es un modo de operación diseñado específicamente para cifrar discos.
         
    Tamaño de clave : 512 bits (256 bits para cada una de las dos claves necesarias en el modo XTS).
    Hashing : Argon2id o PBKDF2 (para derivar la clave maestra desde la contraseña).
        Argon2id  es el método recomendado en LUKS2 debido a su resistencia contra ataques de fuerza bruta.
         
    Iteraciones : El número de iteraciones se ajusta automáticamente para proporcionar un tiempo de derivación seguro (generalmente entre 1 y 2 segundos).

 %%

```bash
cryptsetup luksFormat /dev/vda2
```
Cifrado de disco:
![[Pasted image 20250424172534.png]]

Para poder seguir instalando en la particion debemos abrirla con el siguiente comando 
```bash
cryptsetup open /dev/vda2 cryptroot
```
![[Pasted image 20250424172632.png]]
Si nos fijamos en la salida lsblk veremos que la particion /dev/vda2 contiene un volumen crypt; para crear el sistema de archivos devemos dirigirnos a `/dev/mapper`
![[Pasted image 20250424172906.png]]

Formateamos la particion del sistema con el sistema de archivos `ext4`

```bash
mkfs.ext4 /dev/mapper/cryptroot
```
![[Pasted image 20250424172749.png]]

# Montar particiones y chroot

Vamos a montar las pariticiones para proceder con la instalacion 

```bash
mount /dev/mapper/cryptroot /mnt
mkdir /mnt/boot
mount /dev/vda1 /mnt/boot
```
![[Pasted image 20250424173141.png]]

Usamos [pacstrap](https://wiki.archlinux.org/title/Pacstrap) para instalar el sistema base: 

```bash
pacstrap /mnt base linux linux-firmware nano vim dhcpcd
```
Aqui indicamos paquetes que necesitemos para la instalacion del OS , podemos instalar mas a posteriori pero vamos a necesitar lo mas basico ya que una vez reiniciemos post instalacion si no le instalamos un paquete como `dhcpd` no tendremos conexion con la red y tendremos que retomar desde esta parte de la instalacion 

![[Pasted image 20250424173518.png]]
Esto iniciara la instalacion de los paquetes necesarios para arch base. 

Antes del `chroot` vamos a generar el fstab para que las particiones se monten donde tienen que estar al reiniciar el sistema operativo 

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

![[Pasted image 20250424173952.png]]

Ahora si podemos entrar en el chroot ; esto nos simula el sistema operativo dentro del /mnt y fuera del disco de instalacion , es crucial este paso para seguir con las configuraciones 
```bash
arch-chroot /mnt
```
![[Pasted image 20250424174327.png]]
Observamos que las particiones ya no estan montadas sobre `/mnt`

###  **Configurar el idioma y la zona horaria**

Este paso es muy sencillo

Editamos el archivo `/etc/locale.gen` y descomentamos nuesro idioma`es_ES.UTF-8 UTF-8`

![[Pasted image 20250424174707.png]]

usamos `locale-gen` para sincronizar 
![[Pasted image 20250424174753.png]]

Configuramos la zona horaria

creamos un synlink y sincronizamos
```bash
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc
```
![[Pasted image 20250424174911.png]]

### Nombre del host y Usuarios

El nombre del host se lee del archivo `hostname`:
```bash
echo "guarchdian" > /etc/hostname
```

Creamos el primer usuario del sistema `salva`

```bash
useradd -m -G wheel Salva
passwd Salva
passwd root
```

![[Pasted image 20250424175131.png]]

### Grub

Para iniciar el sistema necesitaremos instalar grub. e indicarle que el disco esta cifrado.
```bash
pacman -S grub efibootmgr
```
![[Pasted image 20250424175510.png]]
Si analizamos la salida vemos como grub genera automaticamente la configuracion con
` grub-mkconfig -o /boot/grub/grub.cfg` pero debemos hacer un par de configuraciones mas para indicarque que estamos ante un sistema con LUKS
#### **Configurar GRUB para LUKS**

Editamos el archivo `/etc/default/grub` para asegurarte de que GRUB pueda desbloquear el disco cifrado durante el arranque.

```bash
GRUB_ENABLE_CRYPTODISK=y
GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:cryptroot root=/dev/mapper/cryptroot"
```


![[Pasted image 20250424175944.png]]
Guardamos y generamos de nuevo la configuracion

```bash
grub-mkconfig -o /boot/grub/grub.cfg
grub-install --target=i8360-pc /dev/vda
```

Es importante saber si estamos instalando grub en una particion EFI o sobre una particion BIOS
![[Pasted image 20250424182906.png]]

![[Pasted image 20250424183054.png]]


Con todo esto configurado podemos 
iniciar el sistema y ver si podemos iniciar arch linux sin el disco de instalacion 

	1 - salimos del chroot (exit)
	2 - cerramos cryptroot1 - salimos del chroot (exit)
	2 - cerramos cryptroot
	3- reiniciamos
	3- reiniciamos

![[Pasted image 20250424183252.png]]




# 3. Migracion al homeserver

En pos de la presentcion y a poder anadir servicios web/bases de datos/ ssh accesible desde fuera voy a migrar GuARCHdian a mi homeserver. mi homeserver es el siguiente:

- [![Beelink Mini S12 Pro Mini PC, Mini Ordenador de Sobremesa con Alder Lake-N N100, 16G SO-DIMM DDR4 +500GB M.2 2280 SATA3 SSD, WIFI6, Dual HDMI, Pantalla Dual, 1000Mbps, BT 5.2](https://m.media-amazon.com/images/I/61dO3+dHD0L._SS142_.jpg)](https://www.amazon.es/dp/B07RNKFJHT?ref=ppx_yo2ov_dt_b_fed_asin_title)
    
    [Beelink Mini S12 Pro Mini PC](https://www.amazon.es/dp/B07RNKFJHT?ref=ppx_yo2ov_dt_b_fed_asin_title)

Para la migracion tuve que hacer algunas configuraciones extas; por ejemplo cambiar que el firewall que usa el sistema de virualizacion `virsh` sea `IPTABLES` en vez de `nf-tables` que usa por defecto; esto nos permitira configurar de forma mas sencilla y como vimos en clase la NAT que use la maquina y poder hacer fowarding de forma mas comoda desde el host;

tambien cambiamos el motor de virtualizacion de video ya que el que estaba usando no lo soportaba el NUC .

El host se trata de un arch linux configurado por defecto ; el host no va a correr ningun servicio pero si que va a hacer de fowarder para que las conexiones pasen a guarchdian haciendo que todo servicio expuesto al exterior este dentro de guarchdian . 

Ahora bien ; necesitamos conectarnos a la pantalla de la maquina ; como lo hacemos?

Tenemos varias opciones; podriamos configurar un servidor VNC o SPICE , pero como necesitamos bootear desde el grub con una password para desencriptar el disco vamos a configurar el ssh para poder compartir programas graficos desde el propio ssh ; de esta manera ademas de enviar el trafico encriptado podremos administrar la maquina en remoto aunque necesitemos reiniciarla.

![[Pasted image 20250426130233.png]]


Para poder transmitir programas graficos en el servidor tambien he tenido que instalar `xorg` para que se gestione el entorno grafico y las variables `$DISPLAY`
![[Pasted image 20250426131628.png]]

Otro error que tuve es que como root no se exportaban las variables ni el .Xautority como me logeo por ssh hasta el usuario sin privilegios por cuestiones de seguridad tuve que realizar las siguientes configuraciones 

## Qué configuraciones hicimos?

1. **Permitimos que el usuario `root` use el servidor X**:
    
    - Con `xhost +SI:localuser:root` le dijimos al Xserver:  
        **"Confía en el usuario root para mostrar ventanas"**.
        
2. **Configuramos `DISPLAY` y `XAUTHORITY` en root**:
    
    - `DISPLAY` le dice a los programas **a qué Xserver** deben conectarse (el de tu sesión SSH).
        
    - `XAUTHORITY` es el **archivo de autenticación** que permite acceso seguro al Xserver.
        

---

##  ¿Por qué necesitamos eso?

- **root no hereda** la sesión gráfica automáticamente.
    
- Necesitamos **darle permiso** explícito (con `xhost`) y decirle **cómo encontrar el servidor X** (con `DISPLAY` y `XAUTHORITY`).
    

---

##  ¿Cómo hacerlo permanente?

Para no repetir cada vez:

1. **Agrega en el `.bashrc` o `.zshrc` de root**:
```bash
export DISPLAY=localhost:10.0
export XAUTHORITY=/home/cher0/.Xauthority
```

_(Reemplaza `/home/usuario/` por el path correcto de tu usuario)_

2. **Agregamos también en tu usuario normal (no root)** el comando:
en la .bashrc
```bash
xhost +SI:localhuser:root
```


![[Pasted image 20250426132029.png]]

Tuve varios problemas con la arquitectura de la maquina ya que las versiones de qemu difieren entre el arch de mi servidor y el debian donde monte la maquina pero despues de cambiar la arquitectura en el xml funciono:
![[Pasted image 20250426142000.png]]
Tuve que cambiar la arquitectura en la siguiente linea del xml:
![[Pasted image 20250426142139.png]]

![[Pasted image 20250426141802.png]]


# 3 . Primer boot y configuraciones

Una vez instalado vemos como GRUB al reiniciarse la maquina virtual nos pide una contrasena para acceder al disco encriptado:

![[Pasted image 20250424183420.png]]
En este punto tuve varios problemas a la hora de entrar al sistema desde grub ; y es que GRUB tiene limitaciones con LUKS2 y no soporta el algoritmo Argon2id. 
Despues de varajar muchas opciones reinstale grub con los modulos necesarios y ademas cambie el tipo de key 

```bash
sudo cryptsetup luksConvertKey --pbkdf pbkdf2 /dev/vda2  # Convierte la clave existente

#  añade una nueva clave compatible:
sudo cryptsetup luksAddKey --pbkdf pbkdf2 /dev/vda2
```

![[Pasted image 20250424192239.png]]


De esta manera pase lo que pase aunque nos modifiquen el grub para entrar en la maquina el disco encriptado es indescifrable sin el uso de la password. Mas adelante veremos como bastionar mas el arranque.

# Reglas de Iptables

Ahora que ya tenemos la maquina corriendo sin problemas es hora de empezar con el bastionado de servicios; lo primero que quiero implementar es un ssh seguro ; antes de implementar medidas de bastionado como port knocking necesitamos poder comunicarnos por ssh a la maquina desde cualquier sitio; para ello tengo que implementar reglas de iptables en el homeserver para que me redirijan el puerto ssh de la maquina virtual(puerto 22) al host(usaremos el puerto 2029 a modo de medida de seguridad [no usaremos el 22 ])

```text
┌───────────────────────────┐
│       Red Doméstica       │
│      (Home Network)       │
│                           │
│   ┌────────────────────┐  │
│   │ Dispositivo externo│  │
│   └────────────────────┘  │
│           ↓               │
│   Paquete TCP/IP          │
│ Destino: 192.168.0.9:2029 │
└───────────────────────────┘
            ↓
┌───────────────────────────┐
│           Host            │
│   IP: 192.168.0.9         │
│                           │
│  Regla iptables:          │
│  - Redirige puerto 2029 → │
│    puerto 22              │
│  - Destino: 192.168.122.16│
└───────────────────────────┘
            ↓
┌───────────────────────────┐
│      Máquina Virtual      │
│  IP: 192.168.122.16       │
│                           │
│  Servicio SSH escuchando  │
│    en el puerto 22        │
└───────────────────────────┘
```

## 1 Instalar openssh 
No voy a explicar mucho aqui una imgane vale mas que mil palabras

![[Pasted image 20250426144236.png]]

## 2 . Reddireccion
Primero observamos que el host tenga conexion con la VM
```bash
[root@ARCHipielago images]# sudo virsh net-info default

Name:           default
UUID:           f8313270-7029-4ebe-982a-56e10c4b8704
Active:         yes
Persistent:     yes
Autostart:      yes
Bridge:         virbr0


```
![[Pasted image 20250426145203.png]]

Para permitir que el host reenvíe el tráfico hacia la máquina virtual, habilita el reenvío de paquetes en el kernel:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

![[Pasted image 20250426144902.png]]

Las reglas deben de ser las siguientes

```bash
# Permitir el tráfico entrante al puerto 2029
sudo iptables -A INPUT -p tcp --dport 2029 -j ACCEPT

# Redirigir el tráfico del puerto 2029 al puerto 22 de la máquina virtual
sudo iptables -t nat -A PREROUTING -p tcp --dport 2029 -j DNAT --to-destination 192.168.122.16:22

# Permitir el reenvío del tráfico hacia la máquina virtual
sudo iptables -A FORWARD -p tcp -d 192.168.122.16 --dport 22 -j ACCEPT
```

Tambien debemos abrir el puerto en el router:
![[Pasted image 20250426145502.png]]

Una vez abierto el puerto podemos verificar con tcpdump si nos llegan los paquetes desde el exterior:

```bash
[root@ARCHipielago] tcpdump -i enp1s0 port 2029 -n -vv
```
donde:
- `-i enp1s0`: Especifica la interfaz de red del servidor .
- `port 2029`: Filtra solo los paquetes relacionados con el puerto `2029` .
- `-n`: Evita la resolución de nombres.
- `-vv`: Muestra información detallada sobre los paquetes.

![[Pasted image 20250426150126.png]]

Nos llega conexion del exterior! (apunte a mi dns desde los datos del movil)


ahora las iptables para que pase el trafico son las siguientes
# 4.Descripción de las reglas `iptables` configuradas

#### 1. **Tabla `nat/PREROUTING`**
- **Regla DNAT:**
  - Redirige el tráfico entrante en el puerto **2029** del host (`192.168.0.9`) hacia el puerto **22** de la máquina virtual (`192.168.122.14`).
  - Comando:
    ```bash
    iptables -t nat -A PREROUTING -i enp1s0 -d 192.168.0.9 -p tcp --dport 2029 -j DNAT --to-destination 192.168.122.99:22
    ```

#### 2. **Tabla `nat/POSTROUTING`**
- **Regla MASQUERADE:**
  - Modifica la dirección de origen del tráfico enviado a la máquina virtual para que parezca que proviene del host.
  - Comando:
    ```bash
    iptables -t nat -A POSTROUTING -o virbr0 -d 192.168.122.14 -p tcp --dport 22 -j MASQUERADE
    ```

#### 3. **Tabla `filter/FORWARD`**
- **Permitir tráfico hacia la MV:**
  - Permite el tráfico redirigido desde el host hacia el puerto **22** de la máquina virtual.
  - Comando:
    ```bash
    iptables -A FORWARD -i enp1s0 -o virbr0 -d 192.168.122.99 -p tcp --dport 22 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    ```

- **Permitir tráfico de retorno desde la MV:**
  - Permite el tráfico de retorno desde el puerto **22** de la máquina virtual hacia el host.
  - Comando:
    ```bash
    iptables -A FORWARD -i virbr0 -o enp1s0 -s 192.168.122.99 -p tcp --sport 22 -m state --state ESTABLISHED,RELATED -j ACCEPT
    ```


Las reglas permiten redirigir el tráfico SSH entrante en el puerto **2029** del host hacia el puerto **22** de la máquina virtual (`192.168.122.199').
El tráfico redirigido se modifica con `MASQUERADE` para ocultar la dirección de origen.
Las reglas en la tabla `FORWARD` garantizan que el tráfico fluya correctamente entre el host y la máquina virtual.


# Red bridge (DMZ self-made)

Durante la instalacion me entro curiosidad por saber como montar mi propia red bridge para que de un rj-45 salga la ip de mi MV ; virtualbox lo hace muy sencillo pero con KVM tenemos que ser mas técnicos; 

Para crear una red bridge primero nos debemos descargar el paquete [bridge-utils](bridge-utils) 

```bash
sudo pacman -S bridge-utils
```

El objetivo es dividir nuestra red principal `enp1s0` en ARCHipielago para que nos cree una interfaz de red con una ip  en el mismo rango que la red local en nuestro caso `192.168.0.99/24` para la interfaz `br0` de nuestro guarchdian
### Configuracion del bridge

Anadimos el bridge con el siguiente comando 

```bash
brctl addbr br0
```

Esto nos crea una interfaz de red sin ip en nuestro sistema

Ahora debemos de anadir que interfaz nos dara conexion como si fuese una nat

```bash
brctl addif br0 enp1s0
```

le anadimos una direccion ip:

Esta ip nos la va a usar el host(archipielago):
```bash
ip addr add 192.168.0.100/24 dev br0
```

Una vez configurada podemos levantarla

```bash
ip link set br0 up
```

Y antes de conectarla a nuestra VM debemos anadir una regla de IPTABLES ; no la voy a hacer fija ya que se activara gracias a un daemon del sistema

```bash
iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
```

Con esto tenemos configurado la red bridge; para conectarlo a kvm debemos editar el .xml de nuestra VM de qemu

```bash
sudo virsh edit guarchdian
```
Añadimos:
```bash
<interface type='bridge'>
  <source bridge='br0'/>
  <model type='virtio'/>
</interface>
```

El problema de esta configuración es que no es permanente; yo decidí crear un daemon del sistema en ``/lib/systemd/system/`` ; yo llame al mio `qemu-bridge.service`

```java
[Unit]
Description=Setup qemu network bridging
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/brctl addbr br0
ExecStart=/usr/sbin/brctl addif br0 enp1s0
ExecStart=/usr/sbin/ip addr add 192.168.0.100/24 dev br0
ExecStart=/usr/sbin/ip link set br0 up
ExecStart=/usr/sbin/iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
ExecStop=/usr/sbin/ip link set br0 down
ExecStop=/usr/sbin/brctl delbr br0

[Install]
WantedBy=multi-user.target
```
De esta manera si iniciamos el servicio se inician todos los comandos necesarios y si se para se borran las normas para que no nos quedemos sin conexión de red .

Para hacerlo persistente:
```bash
systemctl enable qemu-bridge && systemctl start qemu-bridge
```

![[Pasted image 20250426213730.png]]

Ahora para la configuración de red en el ARCHGUARDIAN vamos a usar dhcpd para ponernos las ips estáticas:
Para ello modificamos el `dhcpcd`
en `/etc/dhpcd.conf`

![[Pasted image 20250426213904.png]]

Reiniciamos el servicio:

```bash
sudo systemctl restart dhcpcd
```

IP a podemos mirar nuestras interfaces:

![[Pasted image 20250426214011.png]]

## DMZ

Ahora que estamos conectados a la red bridge se me ocurrió que podría montar mi propia DMZ para que ARCHGUARDIAN en caso de ser vulnerado (imposible) no pueda acceder a ningún sistema de la 192.168.0.0/24

Para conseguir esto nuestros objetivos principales son:

1. Aislar `guarchdian` (en la DMZ) del resto de la red interna.
2. Permitir tráfico HTTPS desde Internet hacia `guarchdian`.
3. Bloquear todo el tráfico desde `guarchdian` hacia la red interna (`192.168.0.x`), excepto respuestas a conexiones establecidas.

Para comodidad y proposito de este ejercicio he configurado un  script de bash que crea las reglas o las borra segun el argumento.

```bash

#!/bin/bash

# Variables
GATEWAY="192.168.0.1"
LOCAL_NETWORK="192.168.0.0/24"
INTERFACE="enp7s0"

if [ "$EUID" -ne 0 ]; then
  echo "Necesitas ejecutar esto como root."
  exit 1
fi

usage() {
  echo "Uso: $0 {on|off}"
  exit 1
}


enable_dmz() {
  echo " Activando DMZ..."
  iptables -D OUTPUT -d "$LOCAL_NETWORK" -j DROP 2>/dev/null
  iptables -D OUTPUT -d "$GATEWAY" -j ACCEPT 2>/dev/null

  iptables -I OUTPUT 1 -d "$GATEWAY" -j ACCEPT
  iptables -A OUTPUT -d "$LOCAL_NETWORK" -j DROP

  echo " DMZ activada. Solo puedes comunicarte con el gateway ($GATEWAY)."
}


disable_dmz() {
  echo " Desactivando DMZ..."


  iptables -D OUTPUT -d "$LOCAL_NETWORK" -j DROP 2>/dev/null
  iptables -D OUTPUT -d "$GATEWAY" -j ACCEPT 2>/dev/null

  echo " DMZ desactivada. Tráfico normal restaurado."
}


case "$1" in
  on)
    enable_dmz
    ;;
  off)
    disable_dmz
    ;;
  *)
    usage
    ;;
esac
```


Como observamos en la imagen archguardian con el DMZ activo no puede conectarse a otros dispositivos de la red: 

![[Pasted image 20250503031921.png]]

# 5. Primera ejecucion de lynis

Vamos a ejecutar lynis por primera vez para comparar el resultado una vez tengamos bastionado el sistema.
- **Lynis** es una herramienta de auditoría de seguridad diseñada específicamente para sistemas Linux/Unix.
- Realiza un análisis detallado del sistema, incluyendo:
    - Configuración del kernel.
    - Permisos de archivos críticos.
    - Servicios innecesarios activos.
    - Vulnerabilidades conocidas.
    - Configuraciones de red y firewall.

`sudo pacman -S lynis`

```bash
[ Lynis 3.1.4 ]

Resumen del Sistema:
- Sistema Operativo: Arch Linux (Rolling release)
- Kernel: 6.14.3
- Arquitectura: x86_64
- Hostname: no-hostname
- Administrador de paquetes: Pacman

Índice de Fortificación (Hardening Index): 63/100

Warnings:
- FIRE-4512: Reglas de iptables no configuradas.

Suggestions:
1. Bootloader y Arranque:
   - Configurar contraseña en GRUB (BOOT-5122).
   - Endurecer servicios con `systemd-analyze security` (BOOT-5264).

2. Autenticación y Contraseñas:
   - Configurar límites de contraseñas en `/etc/login.defs` (AUTH-9230, AUTH-9286).
   - Instalar un módulo PAM para pruebas de fortaleza de contraseñas (AUTH-9262).
   - Establecer fechas de expiración para cuentas (AUTH-9282).
   - Usar un `umask` más estricto en `/etc/login.defs` (AUTH-9328).

3. Sistemas de Archivos:
   - Separar particiones para `/home` y `/var` (FILE-6310).
   - Restringir opciones de montaje (KRNL-6000).

4. Dispositivos USB y Almacenamiento:
   - Desactivar controladores USB/Firewire si no son necesarios (USB-1000, STRG-1846).

5. Red y Firewall:
   - Verificar si los protocolos `dccp`, `sctp`, `rds` y `tipc` son necesarios (NETW-3200).
   - Configurar reglas de `iptables` (FIRE-4512).

6. SSH:
   - Endurecer configuración de SSH (SSH-7408):
     - Desactivar `AllowTcpForwarding`.
     - Reducir `ClientAliveCountMax` a 2.
     - Cambiar `LogLevel` a VERBOSE.
     - Reducir `MaxAuthTries` a 3.
     - Reducir `MaxSessions` a 2.
     - Desactivar `PermitRootLogin` o restringirlo.
     - Cambiar el puerto SSH predeterminado.
     - Desactivar `TCPKeepAlive` y `AllowAgentForwarding`.

7. Registros y Auditoría:
   - Configurar rotación de logs (LOGG-2146).
   - Habilitar registro remoto (LOGG-2154).
   - Implementar `auditd` para recolección de información de auditoría (ACCT-9628).

8. Banners Legales:
   - Agregar banner legal en `/etc/issue` (BANN-7126).

9. Auditoría y Contabilidad:
   - Habilitar contabilidad de procesos (ACCT-9622).
   - Usar `sysstat` para recopilar datos de auditoría (ACCT-9626).

10. Cifrado y Certificados:
    - Verificar la validez de certificados SSL/TLS instalados (CRYP-7902).

11. Integridad de Archivos:
    - Instalar herramienta de integridad de archivos (FINT-4350).

12. Herramientas de Detección de Malware:
    - Instalar escáner de malware (HRDN-7230).

13. Compiladores:
    - Restringir acceso a compiladores solo al usuario root (HRDN-7222).

14. Sysctl:
    - Ajustar varios parámetros sysctl que difieren del perfil seguro (KRNL-6000).

Componentes Detectados:
- Firewall: ✅ (Instalado, pero sin reglas activas)
- Escáner de Malware: ❌ (No instalado)

Archivos Generados:
- Log file: /var/log/lynis.log
- Report file: /var/log/lynis-report.dat
```

Basado en el reporte de Lynis, tenemos los siguientes puntos clave  para bastionar el sistema:

1. **Firewall:**
    - Configurar reglas de iptables (FIRE-4512)
2. **Contraseñas y autenticación:**
    - Configurar límites de contraseñas en /etc/login.defs
    - Instalar un módulo PAM para fortalecer contraseñas
    - Establecer fechas de expiración para cuentas
3. **SSH:**
    - Endurecer configuración de SSH modificando varios parámetros en sshd_config:
        - AllowTcpForwarding
        - ClientAliveCountMax
        - LogLevel
        - MaxAuthTries
        - MaxSessions
        - PermitRootLogin
        - Puerto alternativo
        - TCPKeepAlive
        - AllowAgentForwarding
4. **Kernel Hardening:**
    - Ajustar varios parámetros sysctl que difieren del perfil seguro
    - Restringir acceso a compiladores
5. **Registro y auditoría:**
    - Configurar rotación de logs
    - Habilitar registro remoto
    - Implementar auditd para recolección de información de auditoría
6. **Sistema de archivos:**
    
    - Separar particiones para /home y /var
    - Restringir opciones de montaje
7. **Seguridad adicional:**
    
    - Instalar herramienta de análisis de vulnerabilidades (arch-audit)
    - Instalar herramienta de detección de rootkits/malware
    - Configurar herramienta de integridad de archivos
8. **Banner legal:**
    
    - Agregar banner legal en /etc/issue

# 6. Hardening del sistema

## **Sysctl tuning**
### **Qué es `/etc/sysctl.d/XX-sysctl.conf`?**

1. **Propósito:**
    
    - Este archivo permite modificar los valores de las variables del kernel (también conocidas como "sysctl parameters") sin necesidad de recompilar el kernel.
    - Las configuraciones aquí definidas se aplican automáticamente al cargar el sistema o cuando se ejecuta el comando `sysctl`.

`/etc/sysctl.d/99-sysctl.conf`


**Formato:**

- Cada línea contiene una variable del kernel y su valor deseado, separados por un signo igual (`=`).
- Ejemplo: `net.ipv4.ip_forward = 0`

le llamamos 99 en referencia  a la ip del sistema pero podemos crear tantos archivos de reglas como queramos

Vamos a tomar las siguientes medidas de seguridad 
```bash
# Protección contra IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Desactivar redirecciones ICMP
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Protección contra SYN flood
net.ipv4.tcp_syncookies = 1

# Desactivar IPv6 si no es necesario
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Evitar que el sistema responda a pings broadcast
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignorar paquetes ICMP malformados
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Protección contra ataques de tiempo (timestamps)
kernel.randomize_va_space = 2

# Limitar el número de conexiones simultáneas
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048

# Desactivar logging innecesario
kernel.printk = 3 4 1 3

# Desactivar core dumps para mayor seguridad
fs.suid_dumpable = 0

# Protección contra ataques de DoS
net.ipv4.tcp_challenge_ack_limit = 999999999
```

Los aplicamos de la siguiente manera 
```bash
[root@GuArchdian sysctl.d]# sysctl -p 99-sysctl.conf 
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
kernel.randomize_va_space = 2
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
kernel.printk = 3 4 1 3
fs.suid_dumpable = 0
net.ipv4.tcp_challenge_ack_limit = 999999999
```

Podemos listar los parametros actuales con el comando: `sysctl -a`

Vamos a probar nuestras medidas de seguridad ;

## ssh 
### **Autenticación y acceso**

Para acceder al sistema ademas de hacerlo como usuario no privilegiado vamos a crear claves ssh para acceder al mismo; en mi caso cree el user `Salva` que no tiene privilegios en el sistema
```bash
[Salva@GuArchdian ~]$ pwd
/home/Salva
[Salva@GuArchdian ~]$ id
uid=1000(Salva) gid=1000(Salva) groups=1000(Salva),998(wheel)
[Salva@GuArchdian ~]$ 
```

Creamos un par de claves ssh  con `ssh-keygen -t ed25519`

```bash
[Salva@GuArchdian ~]$ ssh-keygen -t ed25519
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/Salva/.ssh/id_ed25519): 
Enter passphrase for "/home/Salva/.ssh/id_ed25519" (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/Salva/.ssh/id_ed25519
Your public key has been saved in /home/Salva/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:8ra9B+MBboZpWxwXfLXLs7ttHgC1z6gKO4sjtToXtZE Salva@GuArchdian
The key's randomart image is:
+--[ED25519 256]--+
|         .   o.  |
|          o o .. |
|        .  + ..  |
|       Eo . ..+. |
|      o=S+   o+o |
|     o++* + . .o |
|    ..o*o. =  .. |
|   o +ooooo .  oo|
|   .=..o+.oo  o+o|
+----[SHA256]-----+
```

Ahora podemos copiarnos nuestra clave publica o guardar la privada en un vault de modo que solo personas autorizadas podamos logearnos como Salva; 

Nuesta configuracion actual de ssh debe verse asi

```bash
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes # Implementamos PAM mas adelante;
Protocol 2
Port 22 # dejamos el puerto por defecto ya que las relgas de iptables redirigen el trafico desde la ip-publica por el puerto :2029 haciendolo menos probable a ataques
AllowTcpForwarding no
ClientAliveCountMax 2
LogLevel VERBOSE
MaxAuthTries 1
MaxSessions 2
TCPKeepAlive no
AllowAgentForwarding no
IgnoreRhosts yes
LoginGraceTime 30
UseDNS no
X11Forwarding no
PermitTunnel no
StrictModes yes
PrintLastLog yes
PermitUserEnvironment no
GatewayPorts no
ChallengeResponseAuthentication no
PasswordAuthentication no
KbdInteractiveAuthentication no
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
```

`sudo systemctl restart sshd`

Despues de tomar estas medidas de seguridad aumentamos nuestro score de Hardening segun lynix
![[Pasted image 20250427163110.png]]
#### Port-knocking ssh
Vamos a implementar port-knocking tambien que me parecio muy chulo; desde el repositorio oficial.
`pacman -S knockd`
##### **Configurar `knockd`**

El archivo de configuración principal de `knockd` está ubicado en `/etc/knockd.conf`. Vamos a editarlo para definir las reglas de Port Knocking.

```bash
[options]
    UseSyslog
	interface = enp7s0
[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 5
    command     = /usr/sbin/iptables -I INPUT -s %ip% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 5
    command     = /usr/sbin/iptables -D INPUT -s %ip% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
```

Levantamos el servicio
![[Pasted image 20250427170700.png]]

- [ ] Comprobamos el funcionamiento de la siguiente manera; voy a mandar los paquetes de knock desde mi local (192.168.0.99)

![[Pasted image 20250427171130.png]]

Vemos que recibe la comunicacion !

Ahora para que funcione siempre debemos implementar una regla de iptables en la que el trafico INPUT a ssh haga DROP por defecto

`iptables -A INPUT -p tcp --dport 22 -j DROP`

para guardarlo y hacerlo permanente ejecutamos este oneliner
`[root@GuArchdian ~]# iptables -F INPUT &&  iptables -A INPUT -p tcp --dport 22 -j DROP && iptables-save |  tee /etc/iptables/iptables.rules`

![[Pasted image 20250427171427.png]]

En esta imagen podemos observar como se cierra el servicio;
![[Pasted image 20250427172901.png]]

El funcionamiento es muy limpio y elegante. Basicamente crea una regla en iptables que permite el trafico a esa ip que le manda la secuencia.

![[Pasted image 20250427173531.png]]

Cuando se le manda la secuencia de cierre simplemente elimina esa regla.


#### Port knocking over the internet;

Ya que el servicio ssh es critico para gestionar el sistema y yo no suelo estar mucho por casa debemos permitir que nuestro ssh sea accesible desde internet; para ello debemos abrir a internet los puertos del port kocking ; de esta manera podemos conectarnos siempre que tengamos la  clave publica de los equipos autorizados en el equipo 

Para esto podemos configurar una DNS dinamica en nuestra home net; que a traves de cron va a actualizar nuestra IP publica por si cambia; esto es extremadamente util , yo uso duckdns que es gratuito y actualiza la ip gracias a un curl programado con cronjobs 

![[Pasted image 20250428110502.png]]

La instalacion es sencilla; en cualquier servidor de nuestra home net podemos programar un linux cron job que actualice la ip 

```bash
mkdir duckdns
cd duckdns
vi duck.sh
echo url="https://www.duckdns.org/update?domains=guarchdian&token=fd4341ad-9094-48c1-80dc-d9dca4fe6675&ip=" | curl -k -o ~/duckdns/duck.log -K -
chmod 700 duck.sh
crontab -e
*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

![[Pasted image 20250428111213.png]]

Una vez actualizado vemos si desde otra net podemos resolver el dns

Ya que no tenemos una IP publica estatica es bueno tener una dns dinamica en caso de que nuestro ISP nos cambie de ip publica;

![[Pasted image 20250428111710.png]]

Observamos que nos resuelve perfectamente. ahora debemos abrir los puertos del  port knock para que llegen por internet, yo configure la secuencia en tcp pero podemos hacer que sean paquetes udp

Para configurarlo bien tuve que ajustar el delay de los paquetes del knock ya que dado la distancia los paquetes llegan mas lentos dependiendo de donde estemos . configuramos de nuevo la configuracion del daemon de knock
![[Pasted image 20250428111907.png]]
Tambien cambie el puerto del ssh al 2029 por mas seguridad.

![[Pasted image 20250428112112.png]]

Hice un pequeño diagrama para explicar a groso modo como funcionaria la comunicacion

![[Pasted image 20250428113347.png]]


# Control de acceso
suricata es un ==sistema de detección e prevención de intrusiones en red (IDS/IPS) de código abierto, popularmente utilizado para monitorear y proteger redes de tráfico malicioso==.


Para vigilar las conexiones entrantes y salientes de nuestro sistema vamos a instalar `suricata` y mandar los logs al kibana . 

Vamos a instalar `suricata` en ARCHIPIELAGO ya que gracias a ARCHIPIELAGO nos llegan los paquetes de red a guARCHdian. es decir. toda comunicacion pasa por ARCHIPIELAGO por lo que vamos a usar ARCHIPIELAGO para esnifar los paquetes de red.

```bash
sudo pacman -S suricata
```

La interfaz que vamos a vigilar es la interfaz puente. Si hacemos un tcpdump por esa intervaz y hacemos ping desde ARCHGUARDIAN vemos como todos los paquetes pasan por ahi

```bash
23: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    inet 192.168.0.100/24 scope global br0
```

Suricata no esta dentro de los paquetes de pacman  por lo que vamos a necesitar instalarlo desde el [AUR](https://wiki.archlinux.org/title/AUR_\(Espa%C3%B1ol\) "AUR (Español)").
```bash
cd /tmp
git clone https://aur.archlinux.org/suricata.git 
cd suricata
makepkg -si

```

![[Pasted image 20250501161757.png]]

## Suricata conf

Editamos el archivo de configuracion
```bash
sudo nano /etc/suricata/suricata.yaml
```
Modificamos el HOME_NET para mejor configuracion de las reglas 
![[Pasted image 20250501162334.png]]
Modificamos la interfaz de escucha ; en mi caso la `br0`
![[Pasted image 20250501162100.png]]
Revisamos donde esta el archivo de reglas
![[Pasted image 20250501162200.png]]

**Iniciar Suricata**
```bash
sudo mkdir -p /var/log/suricata
sudo chown suricata:suricata /var/log/suricata
sudo systemctl enable --now suricata
```
![[Pasted image 20250501162540.png]]

## Rules file

Para nuestras reglas he tenido en cuenta:

- Conexiones inesperadas salientes (potencial exfiltración o reverse shell).
    
- Tráfico inusual en puertos típicos de administración.
    
- Payloads sospechosos en protocolos comunes (HTTP, DNS, ICMP, SSH).
    
- Actividades típicas de C2 (Command & Control).
    
- Evitar falsos positivos sobre tráfico legítimo (filtrado básico).

```bash
# reverse shells
alert tcp $HOME_NET any -> any any (msg:"ALERTA: Posible Reverse Shell por bash"; flow:established,to_server; content:"/bin/bash"; nocase; sid:1000001; rev:1;)
alert tcp $HOME_NET any -> any any (msg:"ALERTA: Posible Reverse Shell con perl"; flow:established,to_server; content:"perl -e"; nocase; sid:1000002; rev:1;)
alert tcp $HOME_NET any -> any any (msg:"ALERTA: Posible Reverse Shell con python"; flow:established,to_server; content:"python -c"; nocase; sid:1000003; rev:1;)

# Netcat
alert tcp $HOME_NET any -> any any (msg:"ALERTA: Posible uso de netcat (nc)"; flow:established,to_server; content:"nc "; nocase; sid:1000004; rev:1;)

#Http
alert http $HOME_NET any -> any any (msg:"HTTP: Comando sospechoso en URL"; flow:to_server,established; http.uri; content:"/bin/bash"; nocase; sid:1000010; rev:1;)
alert http $HOME_NET any -> any any (msg:"HTTP: Comando sospechoso en User-Agent"; flow:to_server,established; http.user_agent; content:"curl"; nocase; sid:1000011; rev:1;)

#c2
alert tcp $HOME_NET any -> any [6667,1337,8081,8443] (msg:"ALERTA: Posible canal de C2 saliente"; flow:to_server,established; sid:1000020; rev:1;)

#trafico a internet
alert ip $HOME_NET any -> any any (msg:"ALERTA: Trafico saliente hacia Internet"; sid:1000030; rev:1;)

#payloads
alert ip $HOME_NET any -> any any (msg:"ALERTA: Comando sospechoso en payload"; content:"/dev/tcp/"; nocase; sid:1000040; rev:1;)
alert ip $HOME_NET any -> any any (msg:"ALERTA: Uso de bash -i"; content:"bash -i"; nocase; sid:1000041; rev:1;)

```
Modificamos el yaml:
![[Pasted image 20250501163126.png]]

Le damos permisos al archivo de reglas:

`sudo chown suricata:suricata /var/lib/suricata/rules/guarchdian.rules`

Verificamos que las alertas se estan generando:
![[Pasted image 20250501172236.png]]

### enviar los logs a Kibana

Para mandar los logs generados por suricata debemos configurar una cadena completa de monitoreo:

Suricata → Filebeat → Elasticsearch → Kibana.

Devemos activar en el `.yml` del suricata los outputs tipo json a los logs. esto es conocido como `eve-log`

```bash
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: /var/log/suricata/eve.json
      types:
        - alert
        - dns
        - http
        - tls
        - flow
        - ssh
```

Instalamos fileBeat en nuestro ARCHIPIELAGO para que parsee los logs a ElasticSearch

Debemos instalar filebeat de la misma manera que suricata 
https://aur.archlinux.org/packages/filebeat-bin

habilitamos el modulo suricata en filebeat:

```bash
sudo filebeat modules enable suricata
```
![[Pasted image 20250501172854.png]]

modificamos el yml que le indica donde apuntar para mandar los logs a nuestro servidor suricata
![[Pasted image 20250501173025.png]]
lo mismo para kibana
![[Pasted image 20250501173202.png]]
Una vez configurado iniciamos Filebeat

```bash
sudo systemctl enable --now filebeat
```
![[Pasted image 20250501174238.png]]

Observamos que los logs se estén enviando correctamente:
![[Pasted image 20250501190540.png]]

# 7. PAM

PAM es un sistema modular que permite a los servicios del sistema (como SSH) delegar la autenticación de usuarios a diferentes módulos. Esto permite personalizar el proceso de autenticación sin modificar directamente el servicio.

- **Módulos PAM** : Son bibliotecas que implementan diferentes métodos de autenticación (contraseñas, tokens, biometría, etc.).
- **Archivos de configuración** : Los archivos en `/etc/pam.d/` definen cómo se comporta la autenticación para cada servicio.
- **Servicios** : SSH, login, su, etc., utilizan PAM para autenticar usuarios.
## Autenticacion con llave electronica 

Para usar nuestro `flippe zero` como llave electronica vamos a necesitar lo sigiente en guarchdian

`libpam-u2f`: Un módulo PAM que permite la autenticación basada en FIDO2/U2F.

```bash
sudo pacman -S pam-u2f
```

Creamos un directorio para almacenar las claves:

```bash
sudo mkdir -p /etc/u2f_mappings
```

```bash
pamu2fcfg > /etc/u2f_mappings/<username>
```

Creamos en nuestro host la llave generada en nuestra maquina local ya que no vamos a tener acceso fisico al servidor virtualizado 

![[Pasted image 20250428115427.png]]
Transferimos la key generada a nuestro servidor ; por ejemplo por el protocolo `scp` que va cifrado.
Movemos la clave al `/etc` :

![[Pasted image 20250428115836.png]]

Bueno esto no me funciono; Esto se debe a que el archivo `/etc/u2f_mappings/<usuario>` contiene información específica del dispositivo y la configuración del sistema donde se generó. Si intentamos usar un archivo generado en otro host, es probable que la autenticación falle debido a diferencias en el entorno o en las claves registradas. 

Vamos a intentar conectar el USB a la maquina virtual'

Desde el host liastamos usbs
![[Pasted image 20250428121937.png]]

Los anadimos al VM
![[Pasted image 20250428122442.png]]
```bash
<channel type="unix">
  <target type="virtio" name="org.qemu.guest_agent.0"/>
  <address type="virtio-serial" controller="0" bus="0" port="3"/>
</channel>
```

miramos que se anaiese correctamente 
![[Pasted image 20250428122805.png]]
Creamos nuestra key
![[Pasted image 20250428122933.png]]

 **Configura PAM para usar la autenticación U2F**
Nuestro objetivo es que las conexiones ssh esten gestionadas por PAM; pam tiene un archivo especifico para el ssh `/etc/pam.d/sshd` procedemos a editarlo: 

```bash
#%PAM-1.0

auth      required  pam_u2f.so authfile=/etc/u2f_mappings/Salva
account   include   system-remote-login
password  include   system-remote-login
session   include   system-remote-login
```


## auth U2F con ssh

Por desgracia este tipo de autenticacion solo es posible con la conexion directa con el host; No es posible mediante ssh .  Pero si que podemos generar claves ssh que funcionen con U2F 

Las llaves que generaremos que funcionen a traves del flipper U2F seran las ecdsa-sk 
![[Pasted image 20250429132013.png]]

![[Pasted image 20250429132054.png]]
Para hacer esto posible la unica configuracion que debemos anadir al sshd_config es la siguiente

![[Pasted image 20250429132319.png]]

```bash
PubkeyAuthentication yes
```

podemos copiar nuestra clave al servidor ahora; yo configure el sistema de llave publica/privada sin autenticacion U2F ; gracias a esto puedo usar el siguiente comando . Posteriormente borraremos las claves que no sean de U2F para aumentar el bastionado.

```bash
 ssh-copy-id - 2029 -i ~/.ssh/id_ecdsa_sk.pub root@192.168.0.99  
/usr/bin/ssh-copy-id: ERROR: Too many arguments.  Expecting a target hostname, got: 

Usage: /usr/bin/ssh-copy-id [-h|-?|-f|-n|-s|-x] [-i [identity_file]] [-t target_path] [-F ssh_config] [[-o ssh_option] ...] [-p port] [user@]hostname
        -f: force mode -- copy keys without trying to check if they are already installed
        -n: dry run    -- no keys are actually copied
        -s: use sftp   -- use sftp instead of executing remote-commands. Can be useful if the remote only allows sftp
        -x: debug      -- enables -x in this shell, for debugging
        -h|-?: print this help
➜  ~ ssh-copy-id -p 2029 -i ~/.ssh/id_ecdsa_sk.pub root@192.168.0.99 
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/cher0/.ssh/id_ecdsa_sk.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys

Number of key(s) added: 1

Now try logging into the machine, with: "ssh -i /home/cher0/.ssh/id_ecdsa_sk -p 2029 'root@192.168.0.99'"
and check to make sure that only the key(s) you wanted were added.

```

ahora para conectarnos por ssh a la maquina ademas de que solamente nuestro PC tiene autorizacion para hacerlo nos pedira la contrasena que le metimos a la clave anteriormente y ademas una autenticacion en el dispositivo U2F

![[Pasted image 20250429132801.png]]

Probamos en otro ordenador copiandonos la clave privada; instalamos el modulo de pamU2F y ejecutamos el procedimiento de conexion; dado que es la clave privada no necesitamos copiar previamente la publica.

De esta manera ; aunque nos roben la clave privada necesitan tanto una contrasena como un dispositivo **FISICO**.
![[Pasted image 20250429142404.png]]

Repo de [Git](https://github.com/cher0qui/U2F-ssh)




# 8. **Auditing y logging**

El objetivo de la auditoría y el registro (logging) es monitorear y registrar eventos relevantes en el sistema para detectar actividades sospechosas, errores de configuración o posibles intrusiones. Esto incluye:

- **Auditoría** : Monitorear cambios en archivos críticos, permisos, usuarios y comandos ejecutados.
- **Logging** : Registrar eventos del sistema, como inicios de sesión, acceso a archivos y cambios en la configuración

Esto lo aprendí del taller de Manuel (**purplelab ataque monitorizacion y detección**)

Vamos a usar una de las herramientas mas utiles para la monitorizacion de procesos criticos.
## **`auditd` (Linux Audit Framework)**

`auditd` es una herramienta esencial para auditar eventos en el sistema. Permite monitorear:

- Acceso/modificación de archivos críticos (por ejemplo, `/etc/passwd`, `/etc/shadow`).
- Ejecución de comandos privilegiados.
- Cambios en permisos o atributos de archivos.

Para instalarlo :

`pacman -S audit`

Iniciamos y habilitamos el servicio:

```bash
[root@GuArchdian ~]#  systemctl start auditd
[root@GuArchdian ~]#  systemctl enable auditd
```


Podemos crear reglas de auditoria dentro del archivo `/etc/audit/rules.d/audit.rules` en nuestro caso vamos a poner a prueba 3 de ellas:

```bash
# Monitorear cambios en archivos críticos
-w /etc/passwd -p wa -k user_modification
-w /etc/shadow -p wa -k shadow_modification

# Monitorear comandos ejecutados por root
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands

# Monitorear actividades en /var/www/html (servidor web)
-w /srv/http/ -p wa -k www_fim
```
#### **Elementos clave:**

- `-w <ruta>`: Especifica el archivo o directorio que deseas monitorear.
- `-p <permisos>`: Define los tipos de acceso que quieres auditar:
    - `r`: Lectura.
    - `w`: Escritura.
    - `x`: Ejecución.
    - `a`: Atributos (modificación de permisos, propietario, etc.).
- `-k <clave>`: Asigna una etiqueta (clave) a la regla para facilitar la búsqueda en los logs.
- `-a <acción>,<filtro>`: Define una regla más avanzada basada en filtros y acciones.
- `-F <campo>=<valor>`: Filtra eventos específicos (por ejemplo, usuario, proceso, etc.).
- `-S <syscall>`: Monitorea llamadas al sistema específicas (por ejemplo, `execve` para ejecutar comandos).

Por ejemplo para el caso de la segunda regla 
```
-w /etc/shadow -p wa -k shadow_modification
```
- `-w /etc/shadow`: Monitorea el archivo `/etc/shadow`.
- `-p wa`: Audita eventos de escritura (`w`) y cambio de atributos (`a`).
- `-k shadow_modification`: Asigna la clave `shadow_modification` a esta regla.

o por ejemplo la `-s execve`:
* Monitorea la llamada al sistema `execve`, que se usa para ejecutar comandos.
---

las aplicamos con:
```bash
 augenrules --load
```
las verificamos con:
```bash
 auditctl -l
```

![[Pasted image 20250429172444.png]]
	De momento no aplicamos la regla del servidor web porque no instalamos ninguno, en los siguientes apartados haremos una prueba.

consultar los logs generados: 
```bash
 ausearch -i -k <clave>
```

---
### POC

como prueba; vamos a probar a insertar una linea en el /etc/shadow; un simple useradd nos sirve.

```bash
useradd -m -U prueba
```

Y verificamos:

```bash
[root@GuArchdian ~]# ausearch -i -k shadow_modification
----
type=PROCTITLE msg=audit(04/29/25 17:31:20.005:48) : proctitle=useradd -m -U prueba 
type=PATH msg=audit(04/29/25 17:31:20.005:48) : item=4 name=/etc/shadow inode=1836232 dev=fd:00 mode=file,600 ouid=root ogid=root rdev=00:00 nametype=CREATE cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=PATH msg=audit(04/29/25 17:31:20.005:48) : item=3 name=/etc/shadow inode=1836225 dev=fd:00 mode=file,600 ouid=root ogid=root rdev=00:00 nametype=DELETE cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=PATH msg=audit(04/29/25 17:31:20.005:48) : item=2 name=/etc/shadow+ inode=1836232 dev=fd:00 mode=file,600 ouid=root ogid=root rdev=00:00 nametype=DELETE cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=PATH msg=audit(04/29/25 17:31:20.005:48) : item=1 name=/etc/ inode=1835009 dev=fd:00 mode=dir,755 ouid=root ogid=root rdev=00:00 nametype=PARENT cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=PATH msg=audit(04/29/25 17:31:20.005:48) : item=0 name=/etc/ inode=1835009 dev=fd:00 mode=dir,755 ouid=root ogid=root rdev=00:00 nametype=PARENT cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=CWD msg=audit(04/29/25 17:31:20.005:48) : cwd=/root 
type=SYSCALL msg=audit(04/29/25 17:31:20.005:48) : arch=x86_64 syscall=rename success=yes exit=0 a0=0x7ffd0441b490 a1=0x606a160cfba0 a2=0x7ffd0441b400 a3=0x100 items=5 ppid=1225 pid=1443 auid=root uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=pts3 ses=18 comm=useradd exe=/usr/bin/useradd key=shadow_modification 
```
	Recordemos que los logs de auditd se guardan en `/var/log/audit/audit.log `

Si pasamos esta informacion al chatgpt nos explica con todo lujo de detalles como se ha comprometido el sistema.

![[Pasted image 20250429173457.png]]

###  Logs Distribuidos en Arch

Arch Linux usa `systemd-journald` para manejar logs. Aunque `journald` es potente, puedemos configurarlo para enviar logs a un servidor remoto o almacenarlos en archivos persistentes.

**Configuración básica:**
`/etc/systemd/journald.conf`

```bash
[Journal]
Storage=persistent
Compress=yes
ForwardToSyslog=yes #para mandarlo por rsyslog (siguiente apartado)
MaxFileSec=1month
```

Reiniciamos journald y verificamos que los logs se estan guardando:

![[Pasted image 20250429181656.png]]
###  **File Integrity Monitoring (FIM)**


Para nuestro proyecto es importante mantener un registro de la integridad de los archivos criticos, ademas de establecer alertas cuando estos cambien. Una de las herramientas que nos ayuda en este proposito es `%% aide %%`:

	aide es una herramienta de auditoría de integridad de archivos. Su propósito principal es generar y comparar hashes (como MD5, SHA256) de archivos para detectar cambios no autorizados. Esto es útil en entornos donde necesitas asegurarte de que los archivos críticos no han sido modificados .

Y en que podemos usarlo? 

- **Detectar web shells o malware:** En servidores web, puedes usar `hashdeep` para monitorear directorios como `/var/www/html` y detectar archivos sospechosos que hayan sido añadidos o modificados.
    
- **Auditorías forenses:** Si sospechas que tu sistema ha sido comprometido, puedes usar `hashdeep` para identificar qué archivos han sido alterados.


Fichero de configuracion 

```bash
# Definición de grupos de reglas
NORMAL = p+i+n+u+g+s+b+acl+xattrs+sha256
DATAONLY = p+n+u+g+acl+xattrs+sha256
LOGONLY = p+n+u+g+acl+xattrs

# Directorios a monitorizar
/etc NORMAL
/bin NORMAL
/sbin NORMAL
/usr/bin NORMAL
/usr/sbin NORMAL
/boot NORMAL
/root NORMAL

# Excluir directorios temporales
!/tmp
!/var/tmp
!/proc
!/sys
!/dev
!/run

```

El archivo es bastante claro . Monitorizamos los endpoints criticos y evitamos los directorios que nos dejan archivos temporales o que no necesitamos para el analisis (procesos creados por ejemplo que son susceptibles a cambios).

Aide -init nos crea el archivo /etc/aide.db.new donde se guardan nuestros hashes:
```bash
[root@GuArchdian ~]# aide -i
Start timestamp: 2025-05-05 18:16:58 +0200 (AIDE 0.19)
AIDE successfully initialized database.
New AIDE database written to /etc/aide.db.new

Number of entries:	3491

---------------------------------------------------
The attributes of the (uncompressed) database(s):
---------------------------------------------------

/etc/aide.db.new
 SHA256    : xHi42jw2pGDQFGpDYJuAlPEhSiXQXUwC
             /snddC7cslU=
 SHA512    : w4kSPpkq41uxo7PZRHN19KL26dsvKBHy
             FrWf9Meyu1NhjJ9CDiqw+KeVCWqCYzA5
             DsIVw2ce0Z+lK2E+Tg1wug==
 STRIBOG256: 9jUlLHpn3ZXYRJv2XmGqBpXStYZOuJ/y
             hQwUKZpZeRE=
 STRIBOG512: t2OiIbsC4+yhU0Ah9NmdoupIr/YvgJn4
             lMBiTsfIGU9P2zHCNivfb9moHLmejPtp
             jpZHNAv4wf8U5kBnibA4Mg==
 SHA512/256: hVQIPWq4M1SD0vcO/PDHWc0YpTwH80z0
             si3b9K56Hwg=
 SHA3-256  : UDfK27lN34BYvV4hchAapKg9P2IxuSR3
             qILNmCYqk8I=
 SHA3-512  : Gr4/SYMCXKZZcFG79zNHTS8L1C1PVOXO
             lBS7nHaWhJCROgr7/0TY/hB1u/OOb+wJ
             3Q5b4xwKK95pnp8r98BoIg==


End timestamp: 2025-05-05 18:16:58 +0200 (run time: 0m 0s)
[root@GuArchdian ~]# 

```

Voy a crear dos scripts . uno que cree la db de aide para ejecutar con cron a las 12 del mediodia y otro que nos cree una db nueva y compare cambios . Guardamos la salida a los logs 

Script de backup
```bash
[root@GuArchdian ~]# cat scripts/aide_backup.sh 
#!/bin/bash

AIDE_DB_NEW="/etc/aide.db.new"
AIDE_DB="/var/lib/aide/aide.db.gz"
AIDE_DB_OLD="/etc/aide.db.old"
LOG_FILE="/var/log/aide_init.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date) - Iniciando generación de nueva base de datos AIDE" >> "$LOG_FILE"

if aide --init >> "$LOG_FILE" 2>&1; then
    echo "$(date) - AIDE init completado exitosamente" >> "$LOG_FILE"
    
    if [ -f "$AIDE_DB" ]; then
        mv "$AIDE_DB" "$AIDE_DB_OLD"
        echo "$(date) - Base de datos anterior movida a $AIDE_DB_OLD" >> "$LOG_FILE"
    fi
    
    # Mover la nueva base de datos a la posición correcta
    mv "$AIDE_DB_NEW" "$AIDE_DB"
    echo "$(date) - Nueva base de datos movida a $AIDE_DB" >> "$LOG_FILE"
    
    echo "Operación completada. Base de datos actualizada."
    echo "Log guardado en $LOG_FILE"
else
    echo "$(date) - ERROR: Falló la generación de la base de datos AIDE" >> "$LOG_FILE"
    echo "Error al generar la base de datos AIDE. Ver $LOG_FILE para detalles."
    exit 1
fi
```


Este script nos crea un archivo de texto donde vemos todos los hashes creados por aide en /etc/aide.db.new y nos lo mueve a aide.db.old


Este vuelve a ejecutar aide --init. Y compara la salida con nuestro `aide.db.old` de esta forma podemos monitorizar que archivos en el sistema han cambiado
```bash
#!/bin/bash


aide --init

sleep 5

AIDE_DB="/etc/aide.db.new"
AIDE_DB_OLD="/etc/aide.db.old"
TEMP_DIR="/tmp/aide_compare_$(date +%s)"
LOG_FILE="/var/log/aide_compare.log"

# Crear directorios temporales y de logs
mkdir -p "$TEMP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Registrar inicio
echo "$(date) - Iniciando comparación de bases de datos AIDE" >> "$LOG_FILE"

# Verificar que existen ambas bases de datos
if [ ! -f "$AIDE_DB_OLD" ]; then
    echo "$(date) - ERROR: No se encontró la base de datos antigua $AIDE_DB_OLD" >> "$LOG_FILE"
    echo "Error: No se encontró la base de datos antigua."
    echo "Primero ejecute aide_init.sh para crear una base de datos inicial."
    exit 1
fi

if [ ! -f "$AIDE_DB" ]; then
    echo "$(date) - ERROR: No se encontró la base de datos actual $AIDE_DB" >> "$LOG_FILE"
    echo "Error: No se encontró la base de datos actual."
    echo "Primero ejecute aide_init.sh para crear una base de datos inicial."
    exit 1
fi



# Extraer solo las rutas y hashes (columnas 1 y 5)
awk '{print $1, $5}' "/etc/aide.db.old" | sort > "$TEMP_DIR/old_hashes.txt"
awk '{print $1, $5}' "/etc/aide.db.new" | sort > "$TEMP_DIR/new_hashes.txt"

# Comparar y encontrar diferencias
echo "=== Archivos modificados ===" > "$TEMP_DIR/changes.txt"
comm -23 "$TEMP_DIR/new_hashes.txt" "$TEMP_DIR/old_hashes.txt" >> "$TEMP_DIR/changes.txt"

echo "=== Archivos nuevos ===" >> "$TEMP_DIR/changes.txt"
comm -13 "$TEMP_DIR/old_hashes.txt" "$TEMP_DIR/new_hashes.txt" >> "$TEMP_DIR/changes.txt"

echo "=== Archivos eliminados ===" >> "$TEMP_DIR/changes.txt"
comm -23 "$TEMP_DIR/old_hashes.txt" "$TEMP_DIR/new_hashes.txt" >> "$TEMP_DIR/changes.txt"

# Mostrar resultados
cat "$TEMP_DIR/changes.txt"
cat "$TEMP_DIR/changes.txt" >> "$LOG_FILE"

# Limpieza
rm -rf "$TEMP_DIR"

echo "$(date) - Comparación completada" >> "$LOG_FILE"
```

 Ahora creamos un crontab que ejecute el primer script todos los dias a las 12:00 y otro que nos ejecute el segundo a las 00:00. al final del dia tendremos un log completo de todos los cambios en los archivos del sistema
 ![[Pasted image 20250505182454.png]]


## Poc final

Vamos  a instalar un servidor web apache con una vulnerabilidad basica de file Upload . El servidor web apache correra php y sera vulnerable tal cual como DVWA

```bash
sudo pacman -S apache
sudo systemctl enable --now httpd
sudo pacman -S php php-apache
```

Modificamos el module para php en `/etc/httpd/conf/httpd.conf`
```bash
LoadModule php_module modules/libphp.so
AddHandler php-script .php
Include conf/extra/php_module.conf
```

Creamos los directorios:
```bash
sudo mkdir -p /srv/http/uploads
sudo chmod 775 /srv/http/uploads
sudo chown http:http /srv/http/uploads
```

`Index.html`
```html
<!DOCTYPE html>
<html>
<head>
    <title>File Upload</title>
</head>
<body>
    <h1>Upload a File</h1>
    <form action="upload.php" method="post" enctype="multipart/form-data">
        Select file to upload:
        <input type="file" name="uploaded" id="uploaded">
        <input type="submit" name="Upload" value="Upload">
    </form>
</body>
</html>
```

`Upload.php`
```bash
<?php

if( isset( $_POST[ 'Upload' ] ) ) {
    // Define la ruta donde se guardará el archivo
    $target_path  = "/srv/http/uploads/";
    $target_path .= basename( $_FILES[ 'uploaded' ][ 'name' ] );

    // Intenta mover el archivo al directorio de destino
    if( !move_uploaded_file( $_FILES[ 'uploaded' ][ 'tmp_name' ], $target_path ) ) {
        // Si falla
        echo '<pre>Your image was not uploaded.</pre>';
    }
    else {
        // Si tiene éxito
        echo "<pre>{$target_path} successfully uploaded!</pre>";
    }
}

?>
```

![[Pasted image 20250429190543.png]]

Modificamos auditd para que registre comandos por el usuario de apache (en nuestro caso http que estamos en arch linux)
![[Pasted image 20250429192355.png]]
	- `-a always,exit`: Registra tanto el inicio como la salida de la llamada al sistema.
	- `-F arch=b64` y `-F arch=b32`: Monitorea tanto procesos de 64 bits como de 32 bits.
	- `-S execve`: Monitorea la llamada al sistema `execve`, que se utiliza para ejecutar comandos.
	- `-F euid=33`: Filtra las actividades del usuario con UID 33, que corresponde a `http` en Arch Linux.

Una vez todo configurado vamos a subir una rev shell php y ejecutar un par de comandos.
![[Pasted image 20250429193305.png]]
Observamos como se registra todo movimiento por parte del atacante.
# **Logs centralizados**

Es de vital importancia en este proyecto mantener los logs distribuidos entre varios sitios; inclusive fuera de mi red. Por lo que voy a montar un Kibana en un servidor remoto a donde mandaremos los logs ; de foma que podamos visualizarlos de forma sencilla y crear alertas en caso de que ocurra alguna emergencia.

Para este apartado me fue de vital importancia este [articulo](https://stya.medium.com/leveraging-auditd-elk-and-auditbeat-to-have-visibility-and-detection-of-lateral-movement-f92554895cc2) 

	La siguiente configuracion va a ser un pilar en los diferentes puntos del proyecto ya que mandaremos tanto logs del sistema como los de auditd como los de suricata al kibana para tener centralizado y deslocalizado de la maquina en caso de ataque .

Instalaremos **Auditbeat** en archguardian  para recopilar esos logs y enviarlos, y el stack **ELK** (Elasticsearch, Logstash, Kibana) para almacenar, procesar y visualizar los datos en un servidor remoto.

## ¿Qué es Kibana? 

	Kibana  es una herramienta de visualización de datos que se conecta a ELK
	Permite crear tableros (dashboards ) y buscar logs de forma intuitiva.
	Es útil para monitoreo en tiempo real y análisis de seguridad o rendimiento. 

## ¿Qué es Auditbeat? 
Auditbeat  es un agente ligero de Elastic que recopila datos de auditoría del sistema.
Funciona como complemento de auditd  y envía los logs a Elasticsearch  o Logstash.
También puede detectar comportamientos sospechosos usando reglas predefinidas. 

Flujo:

---
auditd registra eventos de seguridad en el sistema (como cambios en .ssh/authorized_keys). > Auditbeat recolecta esos eventos y los envía al stack ELK .

---

### Setup:


Para el setup de kibana me tuve que comer mucho la cabeza ya que uno de mis pocos servidores remoto es un raspberry-pi4 . Al ser procesador ARM muchas versiones de kibana no funcionan  y dockerizarlo fue todo un reto. 

Podemos descargar la ultima version de auditbeat desde [aqui](https://www.elastic.co/downloads/beats/auditbeat?spm=a2ty_o01.29997173.0.0.20a0c921uUJVc8)
## Despliegue de Elasticsearch

Usaremos Docker Compose para desplegar Elasticsearch en modo de nodo único:
```yml
version: '2.2'

services:
  es01:
    image: elasticsearch:8.3.2
    container_name: elasticsearch
    environment:
      - node.name=es01
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx1024m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es-data:/usr/share/elasticsearch/data
      - es-config:/usr/share/elasticsearch/config
    ports:
      - 9200:9200
    networks:
      - elastic

volumes:
  es-data:
    driver: local
  es-config:
    driver: local

networks:
  elastic:
    driver: bridge

```

Una vez iniciado el contenedor:
```bash
docker exec -it elasticsearch bin/elasticsearch-reset-password -u elastic
```


![[Pasted image 20250430123806.png]]


También podemos probar la conexión vía curl:
```bash
curl --user elastic:<contraseña> -k https://localhost:9200/_cluster/health
```
o via web:

![[Pasted image 20250430133404.png]]


Creamos  el token que usará Kibana para autenticarse de forma segura con Elasticsearch:

```bash
docker exec -it elasticsearch bin/elasticsearch-service-tokens create elastic/kibana kibana-token
```
## Despliegue de Kibana

Agregamos Kibana al `docker-compose.yml`, utilizando el token generado y configurando acceso por SSL:


![[Pasted image 20250430123446.png]]
![[Pasted image 20250430133404.png]]
## Despliegue de Kibana

Agrega Kibana al `docker-compose.yml`, utilizando el token generado y configurando acceso por SSL:
```yml
  kibana:
    image: kibana:8.3.2
    container_name: kibana
    environment:
      SERVER_NAME: kibana.local
      SERVER_PORT: 5601
      ELASTICSEARCH_HOSTS: '["https://es01:9200"]'
      ELASTICSEARCH_SERVICEACCOUNTTOKEN: "AAEAAWVsYXN0aWxxxx"
      ELASTICSEARCH_SSL_VERIFICATIONMODE: "none"
    ports:
      - 5601:5601
    volumes:
      - kibana-config:/usr/share/kibana/config
    networks:
      - elastic
```

Y un volumen de kibana

```yml
volumes:
  kibana-config:
    driver: local
```
![[Pasted image 20250430134136.png]]
Con esta configuración:

- **Elasticsearch** y **Kibana** se ejecutan con Docker en Arch Linux sobre Raspberry Pi 4.
    
- El tráfico entre ambos servicios está cifrado (aunque la verificación del certificado está deshabilitada en esta configuración básica).
    
- La autenticación se realiza usando un **token de servicio**, que es el método recomendado para evitar el uso del usuario `elastic`.

```bash
sudo ./auditbeat -e -v
```

![[Pasted image 20250430133447.png]]
![[Pasted image 20250430134136.png]]

```bash
docker exec -it elasticsearch bin/elasticsearch-create-enrollment-token -s kibana
```

```bash
docker exec -it kibana ./bin/kibana --enrollment-token=<tu_token_aqui>
```


Una vez configurado observamos que se están enviando paquetes desde nuestro archguardian.
![[Pasted image 20250430143301.png]]

![[Pasted image 20250430145815.png]] 

# AppArmor
https://wiki.archlinux.org/title/AppArmor

AppArmor es un módulo de seguridad del kernel Linux que permite restringir las capacidades de los programas mediante perfiles de seguridad. A diferencia de SELinux, AppArmor es más sencillo de configurar y se basa en rutas de archivos para definir políticas. Es una herramienta esencial para el bastionado de sistemas, ya que reduce la superficie de ataque al limitar las acciones que los servicios pueden realizar.

```bash
pacman -S apparmor
```

Lo inicializamos en el kernel
```bash
sudo systemctl enable apparmor
sudo systemctl start apparmor
```

![[Pasted image 20250504005123.png]]


![[Pasted image 20250504023257.png]]
# . Estructura de un Perfil


Un perfil de AppArmor define qué archivos puede leer/escribir un programa y qué capacidades del sistema puede usar. Los perfiles se almacenan en `/etc/apparmor.d/`.

por ejemplo:
```bash
#include <tunables/global>

/path/to/executable {
  #include <abstractions/base>

  /dev/tty rw,
  /var/log/service.log w,
  /usr/bin/some-tool ix,
}
```

- `/path/to/executable`: Ruta del binario o script que se protege.
- `/dev/tty rw`: Permite lectura y escritura en `/dev/tty`.
- `/var/log/service.log w`: Permite escribir en el archivo de log.
- `/usr/bin/some-tool ix`: Permite ejecutar (`ix`) la herramienta especificada.
-
Puedemos generar un perfil inicial usando `aa-genprof`:
```bash
sudo aa-genprof /path/to/executable
```

### **Servicios Controlados con AppArmor**

#### **Apache (Servidor Web)**

Apache es un servicio crítico que debe ser protegido para evitar ataques como la ejecución de comandos maliciosos a través de vulnerabilidades web.


Para configurarlo:
```bash
aa-genprof /usr/sbin/httpd
```

**Perfil de Apache:**

```bash
#include <tunables/global>

profile /usr/bin/httpd {
  # Incluye abstracciones básicas
  # Puedes agregar más como network o apache2 si existen en tu sistema
  #include <abstractions/base>
  
  #para que pueda bindearse al 80
  network inet stream,
  capability net_bind_service,
  capability dac_override,
  capability setgid,
  capability setuid,  

  #leer usuario
  /etc/passwd r,
  /etc/group r,
  /etc/nsswitch.conf r,
  /lib/** mr,
  /usr/lib/** mr,
  /etc/httpd/** r,
  /srv/http/** rw,
  /run/httpd/ r,
  /run/httpd/** rw,
  # apache necesita escribir en /tmp
  /tmp/** rw,
  /srv/http/uploads/ rw,
  /srv/http/uploads/* rw, 
     
  /etc/httpd/conf/** r,
  /usr/bin/httpd mr,
  /var/log/httpd/** rw, 


  #deny /srv/http/uploads/* w,
}

```



# Lynis  100% hardening

Para conseguir el 100 % de seguridad en linys vamos a hacer las siguientes configuraciones:
### **Configura contraseña en GRUB**

**Por qué es importante:**  
Evita ataques físicos donde se modifica el arranque del sistema.

![[Pasted image 20250504121721.png]]
![[Pasted image 20250504121748.png]]
![[Pasted image 20250504121852.png]]

### **Endurecer la autenticación de usuarios**

**Requisitos pendientes según Lynis:**

#### A. **Establece expiración de cuentas**

Edita `/etc/default/useradd`:
![[Pasted image 20250504122107.png]]
Editamos `/etc/login.defs`
![[Pasted image 20250504132314.png]]
![[Pasted image 20250504122228.png]]
Y establecemos tiempo limite de cambio de contrasenas para usuarios
```bash
[root@GuArchdian tmp]# sudo chage -M 90 root 
[root@GuArchdian tmp]# sudo chage -M 60 Salva
[root@GuArchdian tmp]# sudo chage -M 60 testuser

```

#### Modulo PAM para contraseñas fuertes
```bash
sudo pacman -S libpwquality
```


lo editamos en `/etc/pam.d/system-login`
![[Pasted image 20250504122424.png]]
verificamos que funciona ya que al crear a testuser e intentar cambiar la password nos salta el PASS_MIN_DAYS de la configuracion de `/etc/login.defs`
![[Pasted image 20250504122748.png]]

### Deshabilitar módulos de red innecesarios  

Lynis recomienda deshabilitar protocolos como dccp, sctp, rds, tipc.

| Módulo  | ¿Qué es?                                  | ¿Por qué se deshabilita?                                                | Riesgo si está activo                      |
|---------|--------------------------------------------|-------------------------------------------------------------------------|--------------------------------------------|
| `dccp`  | **Datagram Congestion Control Protocol**   | No es comúnmente usado, puede ser explotado para ataques de red         | Vulnerabilidades históricas                |
| `sctp`  | **Stream Control Transmission Protocol**   | Pocos usos en servidores típicos, a menudo innecesario                  | Exploits conocidos en el pasado            |
| `rds`   | **Reliable Datagram Sockets**              | Solo usado en clústeres Oracle (RDSv1/RDSv3)                            | Exposición innecesaria en sistemas comunes |
| `tipc`  | **Transparent Inter-Process Communication**| Usado solo en entornos muy específicos como telecomunicaciones          | Superficie de ataque innecesaria           |


Agregamos esto a /etc/modprobe.d/blacklist.conf: 
```bash
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
```

y regeneramos la imagen de `ininitramfs`:
```bash
mkinitcpio -P
```


###  **Rotación de logs**

Lynis avisa si no hay rotación de logs. Usa `logrotate`.

Ejemplo de mi dot  `/etc/logrotate.d/custom`:

```bash
# /etc/logrotate.d/custom
# Configuración personalizada para rotación de logs críticos

/var/log/audit/audit.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0600 root root
    postrotate
        systemctl reload auditd > /dev/null 2>&1 || true
    endscript
}

/var/log/suricata/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
}

/var/log/auth.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
}

/var/log/syslog {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
}

/var/log/messages {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
}
```

| Opción                  | Descripción                                                      |
| ----------------------- | ---------------------------------------------------------------- |
| `daily`                 | Rotación diaria de logs                                          |
| `rotate 7`/`14`         | Número de copias de seguridad de logs a mantener                 |
| `compress`              | Comprime los archivos de log antiguos                            |
| `delaycompress`         | Retrasa la compresión hasta la siguiente rotación                |
| `notifempty`            | No rota el log si está vacío                                     |
| `create 0640 root root` | Crea un nuevo archivo de log con permisos seguros                |
| `postrotate`            | Ejecuta comandos (como recargar servicios) después de rotar logs |
![[Pasted image 20250504123712.png]]


### **Herramienta de detección de malware**

Instalamos rkhunter y establecemos un cronjob para que ejecute analisis periodicos 
```bash
Defaults env_reset, secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
```

![[Pasted image 20250504124416.png]]
## Deshabilitar compiladores para usuarios que no sean root

dentro de `/etc/sudoers`
```bash
Defaults env_reset, secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
```

## Actualizaciones periodicas 


## Logeo de intentos de sesion.

Verificamos que tengamos el modulo de pam
```bash
ls /usr/lib/security/pam_faillock.so

```

modificamos `/etc/pam.d/login`

```bash
#%PAM-1.0

auth        required      pam_nologin.so
auth        required      pam_faillock.so preauth silent deny=5 unlock_time=900  
auth        include       system-local-login
auth        [default=die] pam_faillock.so authfail                               

account     required      pam_faillock.so                                        
account     include       system-local-login

session     include       system-local-login

password    include       system-local-login

```

Observamos que se registran:
![[Pasted image 20250504221816.png]]


### script de ntfy. 

Uso notfy para crear el siguiente script y lo ejecuto con una directiva de PAM

```bash
#!/bin/bash

/usr/bin/curl -d "Inicio de sesion local para:$PAM_USER desde la $PAM_TTY a las [$(date)]" -X POST "http://midns:8888/Guarchdian_login"
```

Y modificamos que ejecute siempre el script el Pam cada vez que se use el comando. por ejemplo `/etc/pam.d/su` :

```bash
auth            optional         pam_exec.so /usr/local/bin/LocalLogin.sh
```

Y el script :
```bash
#!/bin/bash

/usr/bin/curl -d "Inicio de sesion local para:$PAM_USER desde la $PAM_TTY a las [$(date)]" -X POST "http://midns:8888/Guarchdian_login"

exit 0

```

Esto asegura que nos llegen notificaciones al el ntfy
![[Pasted image 20250505005142.png]]
###  ¿Por qué no marca 100 en el _hardening index_?

Aunque el reporte final de Lynis dice "no warnings / no suggestions", **el índice de hardening no depende solo de los fallos activos**, sino también de:

#### **Puntos  que   generan advertencias**

Algunos ejemplos de cosas que nos penalizan:

| Área                          | Solucion                                                                               |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| IDS / IPS                     | Instala y configura una herramienta como Suricata o Snort                              |
| Logging                       | Asegura que los intentos de login fallidos se registren (`pam_faillock`, `journalctl`) |
| Automatización                | Instala una herramienta tipo Ansible/Puppet (aunque sea minimal)                       |
| Plugins Lynis                 | Activa alguno para análisis extra (`/etc/lynis/plugins/`)                              |
| SELinux (opcional en Arch)    | Arch no lo usa por defecto, pero Lynis lo considera                                    |
| Fortalecer `/dev`, `/dev/shm` | Usa `nodev`, `nosuid`, `noexec` en `/etc/fstab`                                        |

En nuestro caso herramientas como `suricata` estan vigilando la red del sistema pero desde otro endpoint. Esto no quiere decir que nuestro arch linux no este bastionado al completo si no que hemos buscado otras maneras de bastionarlo que lynis no contempla

![[Pasted image 20250505183034.png]]]]