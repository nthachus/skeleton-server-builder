## setup-alpine

- keyboard: us us
- host: vm-alpine3
- network: eth0 / dhcp
- password: toor
- timezone: Asia/Ho_Chi_Minh
- proxy: none
- ntp client: none
- mirror: 1 (dl-cdn.alpinelinux.org)
- ssh server: none
- disk(s): sda / sys

## configuration

```bash
#
sed -i 's/_TIMEOUT=[0-9]*$/_TIMEOUT=0/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

#
sed -i 's,^#\(http.*/v3\),\1,' /etc/apk/repositories
apk update
apk upgrade
#apk cache clean

#
#apk search 'open-vm'
apk add --no-cache open-vm-tools openssh-server sudo logrotate ip6tables python3
apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.13/community ufw
rm -rf /var/cache/apk/* /tmp/*
#apk info -vv

#rc-status -a
rc-update add open-vm-tools boot
rc-update add ufw boot
rc-update add sshd

#ufw app list
ufw allow SSH
ufw allow 'WWW Full'
ufw allow 5432/tcp
ufw enable

#
sed -i 's/^# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers
adduser -g 'System Administrator' sysadmin
adduser sysadmin adm
adduser sysadmin wheel

#reboot
sudo passwd -d root
sudo passwd -l root
sudo sed -i 's/#\(PermitRootLogin\).*/&\n\1 no/' /etc/ssh/sshd_config

#sudo ufw status verbose
#sudo dmesg | grep -i ufw
sudo truncate -s0 /var/log/messages /var/log/vmware*.log
```

```bash
#
# libreoffice-writer libreoffice-calc libreoffice-impress
sudo apk add --no-cache postgresql ruby-full file uchardet p7zip graphicsmagick nginx nginx-mod-stream
sudo rm -rf /var/cache/apk/* /tmp/*

sudo rc-update add postgresql
sudo rc-update add nginx
sudo adduser sysadmin www-data

#sudo reboot
sudo sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.6.0/rubygems/validator.rb
sudo sed -i "s/#\(listen_addresses\).*/&\n\1 = '*'/" /etc/postgresql/postgresql.conf
sudo sed -i 's,# IPv6,host\tall\t\tall\t\t192.168.0.0/16\t\tmd5\n&,' /etc/postgresql/pg_hba.conf

sudo truncate -s0 /var/log/messages /var/log/vmware*.log /var/log/postgresql/*.log /var/log/nginx/*.log
```
