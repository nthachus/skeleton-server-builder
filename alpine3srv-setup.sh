#!/bin/sh
set -xe

# Reduce boot time
sed -i 's/_TIMEOUT=[0-9]*$/_TIMEOUT=0/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Configure APK repositories
sed -i 's,^#\(http.*/v3\),\1,' /etc/apk/repositories
apk update
apk upgrade
#apk cache clean

# Install dependencies
#apk search 'open-vm'
apk add --no-cache open-vm-tools sudo logrotate ip6tables \
  postgresql ruby-full file uchardet p7zip graphicsmagick nginx nginx-mod-stream
# libreoffice-writer libreoffice-calc libreoffice-impress
rm -rf /var/cache/apk/* /tmp/*
#apk info -vv

#rc-status -a
rc-update add open-vm-tools boot
rc-update add iptables boot
rc-update add ip6tables boot
rc-update add postgresql
rc-update add nginx

# Setup users
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/*
adduser -g 'System Administrator' -D sysadmin
echo 'sysadmin:abc@123' | chpasswd
adduser sysadmin wheel
adduser sysadmin adm
adduser sysadmin www-data
passwd -d root
passwd -l root

# Configure services
sed -i 's/#\(PermitRootLogin\).*/&\n\1 no/' /etc/ssh/sshd_config
sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.6.0/rubygems/validator.rb
sed -i "s/#\(listen_addresses\)/\1 = '*'\n&/" /usr/share/postgresql/postgresql.conf.sample
sed -i 's,# IPv6,host\tall\t\tall\t\t192.168.0.0/16\t\tmd5\n&,' /usr/share/postgresql/pg_hba.conf.sample
adduser -S -u 82 -D -H -h /var/www -g www-data -G www-data www-data
#sed -i 's/user nginx;/user www-data;/' /etc/nginx/nginx.conf && chown www-data: /var/lib/nginx /run/nginx && chown www-data -R /var/lib/nginx/tmp

# Configure firewall
echo "ip_tables
ip6_tables" > /etc/modules-load.d/iptables.conf

echo "*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:ufw-after-forward - [0:0]
:ufw-after-input - [0:0]
:ufw-after-logging-forward - [0:0]
:ufw-after-logging-input - [0:0]
:ufw-after-logging-output - [0:0]
:ufw-after-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-before-input - [0:0]
:ufw-before-logging-forward - [0:0]
:ufw-before-logging-input - [0:0]
:ufw-before-logging-output - [0:0]
:ufw-before-output - [0:0]
:ufw-logging-allow - [0:0]
:ufw-logging-deny - [0:0]
:ufw-not-local - [0:0]
:ufw-reject-forward - [0:0]
:ufw-reject-input - [0:0]
:ufw-reject-output - [0:0]
:ufw-skip-to-policy-forward - [0:0]
:ufw-skip-to-policy-input - [0:0]
:ufw-skip-to-policy-output - [0:0]
:ufw-track-forward - [0:0]
:ufw-track-input - [0:0]
:ufw-track-output - [0:0]
:ufw-user-forward - [0:0]
:ufw-user-input - [0:0]
:ufw-user-limit - [0:0]
:ufw-user-limit-accept - [0:0]
:ufw-user-logging-forward - [0:0]
:ufw-user-logging-input - [0:0]
:ufw-user-logging-output - [0:0]
:ufw-user-output - [0:0]
-A INPUT -j ufw-before-logging-input
-A INPUT -j ufw-before-input
-A INPUT -j ufw-after-input
-A INPUT -j ufw-after-logging-input
-A INPUT -j ufw-reject-input
-A INPUT -j ufw-track-input
-A FORWARD -j ufw-before-logging-forward
-A FORWARD -j ufw-before-forward
-A FORWARD -j ufw-after-forward
-A FORWARD -j ufw-after-logging-forward
-A FORWARD -j ufw-reject-forward
-A FORWARD -j ufw-track-forward
-A OUTPUT -j ufw-before-logging-output
-A OUTPUT -j ufw-before-output
-A OUTPUT -j ufw-after-output
-A OUTPUT -j ufw-after-logging-output
-A OUTPUT -j ufw-reject-output
-A OUTPUT -j ufw-track-output
-A ufw-after-input -p udp -m udp --dport 137 -j ufw-skip-to-policy-input
-A ufw-after-input -p udp -m udp --dport 138 -j ufw-skip-to-policy-input
-A ufw-after-input -p tcp -m tcp --dport 139 -j ufw-skip-to-policy-input
-A ufw-after-input -p tcp -m tcp --dport 445 -j ufw-skip-to-policy-input
-A ufw-after-input -p udp -m udp --dport 67 -j ufw-skip-to-policy-input
-A ufw-after-input -p udp -m udp --dport 68 -j ufw-skip-to-policy-input
-A ufw-after-input -m addrtype --dst-type BROADCAST -j ufw-skip-to-policy-input
-A ufw-after-logging-forward -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW BLOCK] \"
-A ufw-after-logging-input -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW BLOCK] \"
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -p icmp -m icmp --icmp-type 3 -j ACCEPT
-A ufw-before-forward -p icmp -m icmp --icmp-type 11 -j ACCEPT
-A ufw-before-forward -p icmp -m icmp --icmp-type 12 -j ACCEPT
-A ufw-before-forward -p icmp -m icmp --icmp-type 8 -j ACCEPT
-A ufw-before-forward -j ufw-user-forward
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
-A ufw-before-input -m conntrack --ctstate INVALID -j DROP
-A ufw-before-input -p icmp -m icmp --icmp-type 3 -j ACCEPT
-A ufw-before-input -p icmp -m icmp --icmp-type 11 -j ACCEPT
-A ufw-before-input -p icmp -m icmp --icmp-type 12 -j ACCEPT
-A ufw-before-input -p icmp -m icmp --icmp-type 8 -j ACCEPT
-A ufw-before-input -p udp -m udp --sport 67 --dport 68 -j ACCEPT
-A ufw-before-input -j ufw-not-local
-A ufw-before-input -d 224.0.0.251/32 -p udp -m udp --dport 5353 -j ACCEPT
-A ufw-before-input -d 239.255.255.250/32 -p udp -m udp --dport 1900 -j ACCEPT
-A ufw-before-input -j ufw-user-input
-A ufw-before-output -o lo -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -j ufw-user-output
-A ufw-logging-allow -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW ALLOW] \"
-A ufw-logging-deny -m conntrack --ctstate INVALID -m limit --limit 3/min --limit-burst 10 -j RETURN
-A ufw-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW BLOCK] \"
-A ufw-not-local -m addrtype --dst-type LOCAL -j RETURN
-A ufw-not-local -m addrtype --dst-type MULTICAST -j RETURN
-A ufw-not-local -m addrtype --dst-type BROADCAST -j RETURN
-A ufw-not-local -m limit --limit 3/min --limit-burst 10 -j ufw-logging-deny
-A ufw-not-local -j DROP
-A ufw-skip-to-policy-forward -j DROP
-A ufw-skip-to-policy-input -j DROP
-A ufw-skip-to-policy-output -j ACCEPT
-A ufw-track-output -p tcp -m conntrack --ctstate NEW -j ACCEPT
-A ufw-track-output -p udp -m conntrack --ctstate NEW -j ACCEPT
-A ufw-user-input -p tcp -m tcp --dport 22 -m comment --comment \"SSH\" -j ACCEPT
-A ufw-user-input -p tcp -m multiport --dports 80,443 -m comment --comment \"WWW Full\" -j ACCEPT
-A ufw-user-input -p tcp -m tcp --dport 5432 -m comment --comment \"PostgreSQL\" -j ACCEPT
-A ufw-user-limit -m limit --limit 3/min -j LOG --log-prefix \"[UFW LIMIT BLOCK] \"
-A ufw-user-limit -j REJECT --reject-with icmp-port-unreachable
-A ufw-user-limit-accept -j ACCEPT
COMMIT" > /etc/iptables/rules-save

echo "*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:ufw6-after-forward - [0:0]
:ufw6-after-input - [0:0]
:ufw6-after-logging-forward - [0:0]
:ufw6-after-logging-input - [0:0]
:ufw6-after-logging-output - [0:0]
:ufw6-after-output - [0:0]
:ufw6-before-forward - [0:0]
:ufw6-before-input - [0:0]
:ufw6-before-logging-forward - [0:0]
:ufw6-before-logging-input - [0:0]
:ufw6-before-logging-output - [0:0]
:ufw6-before-output - [0:0]
:ufw6-logging-allow - [0:0]
:ufw6-logging-deny - [0:0]
:ufw6-reject-forward - [0:0]
:ufw6-reject-input - [0:0]
:ufw6-reject-output - [0:0]
:ufw6-skip-to-policy-forward - [0:0]
:ufw6-skip-to-policy-input - [0:0]
:ufw6-skip-to-policy-output - [0:0]
:ufw6-track-forward - [0:0]
:ufw6-track-input - [0:0]
:ufw6-track-output - [0:0]
:ufw6-user-forward - [0:0]
:ufw6-user-input - [0:0]
:ufw6-user-limit - [0:0]
:ufw6-user-limit-accept - [0:0]
:ufw6-user-logging-forward - [0:0]
:ufw6-user-logging-input - [0:0]
:ufw6-user-logging-output - [0:0]
:ufw6-user-output - [0:0]
-A INPUT -j ufw6-before-logging-input
-A INPUT -j ufw6-before-input
-A INPUT -j ufw6-after-input
-A INPUT -j ufw6-after-logging-input
-A INPUT -j ufw6-reject-input
-A INPUT -j ufw6-track-input
-A FORWARD -j ufw6-before-logging-forward
-A FORWARD -j ufw6-before-forward
-A FORWARD -j ufw6-after-forward
-A FORWARD -j ufw6-after-logging-forward
-A FORWARD -j ufw6-reject-forward
-A FORWARD -j ufw6-track-forward
-A OUTPUT -j ufw6-before-logging-output
-A OUTPUT -j ufw6-before-output
-A OUTPUT -j ufw6-after-output
-A OUTPUT -j ufw6-after-logging-output
-A OUTPUT -j ufw6-reject-output
-A OUTPUT -j ufw6-track-output
-A ufw6-after-input -p udp -m udp --dport 137 -j ufw6-skip-to-policy-input
-A ufw6-after-input -p udp -m udp --dport 138 -j ufw6-skip-to-policy-input
-A ufw6-after-input -p tcp -m tcp --dport 139 -j ufw6-skip-to-policy-input
-A ufw6-after-input -p tcp -m tcp --dport 445 -j ufw6-skip-to-policy-input
-A ufw6-after-input -p udp -m udp --dport 546 -j ufw6-skip-to-policy-input
-A ufw6-after-input -p udp -m udp --dport 547 -j ufw6-skip-to-policy-input
-A ufw6-after-logging-forward -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW BLOCK] \"
-A ufw6-after-logging-input -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW BLOCK] \"
-A ufw6-before-forward -m rt --rt-type 0 -j DROP
-A ufw6-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 1 -j ACCEPT
-A ufw6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT
-A ufw6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 3 -j ACCEPT
-A ufw6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 4 -j ACCEPT
-A ufw6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 128 -j ACCEPT
-A ufw6-before-forward -p ipv6-icmp -m icmp6 --icmpv6-type 129 -j ACCEPT
-A ufw6-before-forward -j ufw6-user-forward
-A ufw6-before-input -i lo -j ACCEPT
-A ufw6-before-input -m rt --rt-type 0 -j DROP
-A ufw6-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 129 -j ACCEPT
-A ufw6-before-input -m conntrack --ctstate INVALID -j ufw6-logging-deny
-A ufw6-before-input -m conntrack --ctstate INVALID -j DROP
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 1 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 3 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 4 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 128 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 133 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 134 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 135 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 136 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 141 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 142 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 130 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 131 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 132 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 143 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 148 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 149 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 151 -m hl --hl-eq 1 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 152 -m hl --hl-eq 1 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 153 -m hl --hl-eq 1 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 144 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 145 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 146 -j ACCEPT
-A ufw6-before-input -p ipv6-icmp -m icmp6 --icmpv6-type 147 -j ACCEPT
-A ufw6-before-input -s fe80::/10 -d fe80::/10 -p udp -m udp --sport 547 --dport 546 -j ACCEPT
-A ufw6-before-input -d ff02::fb/128 -p udp -m udp --dport 5353 -j ACCEPT
-A ufw6-before-input -d ff02::f/128 -p udp -m udp --dport 1900 -j ACCEPT
-A ufw6-before-input -j ufw6-user-input
-A ufw6-before-output -o lo -j ACCEPT
-A ufw6-before-output -m rt --rt-type 0 -j DROP
-A ufw6-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 1 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 3 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 4 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 128 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 129 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 133 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 136 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 135 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 134 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 141 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 142 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 130 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 131 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 132 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 143 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 148 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -p ipv6-icmp -m icmp6 --icmpv6-type 149 -m hl --hl-eq 255 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 151 -m hl --hl-eq 1 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 152 -m hl --hl-eq 1 -j ACCEPT
-A ufw6-before-output -s fe80::/10 -p ipv6-icmp -m icmp6 --icmpv6-type 153 -m hl --hl-eq 1 -j ACCEPT
-A ufw6-before-output -j ufw6-user-output
-A ufw6-logging-allow -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW ALLOW] \"
-A ufw6-logging-deny -m conntrack --ctstate INVALID -m limit --limit 3/min --limit-burst 10 -j RETURN
-A ufw6-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix \"[UFW BLOCK] \"
-A ufw6-skip-to-policy-forward -j DROP
-A ufw6-skip-to-policy-input -j DROP
-A ufw6-skip-to-policy-output -j ACCEPT
-A ufw6-track-output -p tcp -m conntrack --ctstate NEW -j ACCEPT
-A ufw6-track-output -p udp -m conntrack --ctstate NEW -j ACCEPT
-A ufw6-user-input -p tcp -m tcp --dport 22 -m comment --comment \"SSH\" -j ACCEPT
-A ufw6-user-input -p tcp -m multiport --dports 80,443 -m comment --comment \"WWW Full\" -j ACCEPT
-A ufw6-user-input -p tcp -m tcp --dport 5432 -m comment --comment \"PostgreSQL\" -j ACCEPT
-A ufw6-user-limit -m limit --limit 3/min -j LOG --log-prefix \"[UFW LIMIT BLOCK] \"
-A ufw6-user-limit -j REJECT --reject-with icmp6-port-unreachable
-A ufw6-user-limit-accept -j ACCEPT
COMMIT" > /etc/iptables/rules6-save

chmod 0600 /etc/iptables/rules*
sed -i 's/\(SAVE_RESTORE_OPTIONS\)=".*"/\1=""/' /etc/conf.d/iptables /etc/conf.d/ip6tables
#dmesg | grep -i ufw

truncate -s0 /var/log/messages /var/log/dmesg /var/log/*.log
#poweroff

# To reduce VMware disk size
#fdisk -l
# sudo zerofree -v /dev/sda3
# sudo vmware-toolbox-cmd disk shrinkonly
