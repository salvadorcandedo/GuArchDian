#!/bin/bash

BBlue='\033[1;34m'
NC='\033[0m'

if [ "$(id -u)" != "0" ]; then
   echo "debes ejecutar este script como root." 1>&2
   exit 1
fi

echo -e "${BBlue}Aplicando hardening a sysctl...${NC}"

cat > /etc/sysctl.d/99-sysctl.conf <<EOF
dev.tty.ldisc_autoload=0
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
vm.mmap_rnd_bits=32
vm.mmap_rnd_compat_bits=16
vm.vfs_cache_pressure = 50
vm.mmap_min_addr = 65536
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.overcommit_memory = 2
vm.overcommit_ratio = 50
vm.unprivileged_userfaultfd=0
kernel.unprivileged_userns_clone=0
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.pid_max = 65535
kernel.msgmnb = 65535
kernel.msgmax = 65535
kernel.printk=3 3 3 3
kernel.unprivileged_bpf_disabled=1
kernel.panic = 10
kernel.panic_on_oops = 1
kernel.modules_disabled = 0
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.shmall = 268435456
kernel.shmmax = 1073741824
kernel.kexec_load_disabled = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.core.bpf_jit_harden = 2
net.core.dev_weight = 64
net.ipv4.conf.all.proxy_arp = 0
net.ipv4.neigh.default.gc_thresh1 = 32
net.ipv4.neigh.default.gc_thresh2 = 1024
net.ipv4.neigh.default.gc_thresh3 = 2048
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_rfc1337 =_
