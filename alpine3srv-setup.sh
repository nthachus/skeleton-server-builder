#!/bin/sh
set -x

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
apk add --no-cache open-vm-tools openssh-server sudo logrotate ip6tables python3 \
  postgresql ruby-full file uchardet p7zip graphicsmagick nginx nginx-mod-stream
# libreoffice-writer libreoffice-calc libreoffice-impress
apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.13/community ufw
rm -rf /var/cache/apk/* /tmp/*
#apk info -vv

#rc-status -a
rc-update add open-vm-tools boot
rc-update add ufw boot
rc-update add sshd
rc-update add postgresql
rc-update add nginx

#ufw app list
ufw allow SSH
ufw allow 'WWW Full'
ufw allow 5432/tcp
ufw enable
#ufw status verbose
#dmesg | grep -i ufw

# Setup users
sed -i 's/^# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers
adduser -g 'System Administrator' -D sysadmin
echo 'sysadmin:abc@123' | chpasswd
adduser sysadmin adm
adduser sysadmin wheel
adduser sysadmin www-data
adduser sysadmin nginx
passwd -d root
passwd -l root

# Configure services
sed -i 's/#\(PermitRootLogin\).*/&\n\1 no/' /etc/ssh/sshd_config
sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.6.0/rubygems/validator.rb
sed -i "s/#\(listen_addresses\)/\1 = '*'\n&/" /usr/share/postgresql/postgresql.conf.sample
sed -i 's,# IPv6,host\tall\t\tall\t\t192.168.0.0/16\t\tmd5\n&,' /usr/share/postgresql/pg_hba.conf.sample

truncate -s0 /var/log/messages /var/log/*.log
#poweroff

# To reduce VMware disk size
#fdisk -l
# zerofree -v /dev/sda3
# vmware-toolbox-cmd disk shrinkonly
