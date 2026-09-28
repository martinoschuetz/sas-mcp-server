[TOC]

# Machine Preparation

## Special preparation for Dual Boot

FIRST Install Windows 10 from an USB Stick (https://www.microsoft.com/de-de/software-download/windows10%20)

Install CentOS Stream from an USB Stick (https://linuxhint.com/install_centos8_stream/)

After Reboot the Grub2 boot manager ist not showing a Windows 10 entry

sudo su -

cat <<EOF > /etc/grub.d/40_custom
menuentry "Windows 10" {
set root=(hd0,1)
chainloader +1
}
EOF

grub2-mkconfig --output= /boot/grub2/grub.cfg

reboot

You should be able to select Windows 10 know.

## Add Visual Studio Code as Editor for Coding and these scripts first

```yum install git
rpm --import https://packages.microsoft.com/keys/microsoft.asc sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

dnf check-update

dnf install code

# Start Visual Studio 
code
# Mark code as a favorite

# exit to normal user

git config --global user.name "Martin Schütz"
git config --global user.email "martin@schuetzens.de"

#change back to super user
su
```

# Install VPN
# https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-centos-8-de

## System Update

```shell
hostnamectl --static set-hostname dach-viya4-k8s
hostnamectl --transient set-hostname dach-viya4-k8s

mkdir /etc/cloud
vi /etc/cloud/cloud.cfg
# preserve_hostname: true

#timedatectl set-timezone UTC

yum install epel-release -y
yum install -y mlocate vim ufw wget git socat htop jq nfs-utils conntrack zip unzip htop tmux mailx at
updatedb
systemctl enable --now atd.service

yum update -y
```

### Disable SELinux

```shell
# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

## Add Docker (19.03)

```shell
yum install -y yum-utils

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum install -y --allowerasing containerd.io

yum install -y  docker-ce  docker-ce-cli

groupadd -f docker
usermod -aG docker martin

systemctl enable docker
systemctl start docker

cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": [ "native.cgroupdriver=systemd" ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [ "overlay2.override_kernel_check=true" ]
}
EOF

systemctl restart docker
```



## Set up virtual NIC to ensure stable IP address

### Add virtual NIC IP adress to Linux /etc/hosts
```shell
# vi /etc/hosts
192.168.100.199  dach-viya4-k8s
```

```shell
modprobe dummy
ip link add dummy0 type dummy
ip link set name eth10 dev dummy0
ip addr add 192.168.100.199/24 brd + dev eth10
ifconfig eth10 up
# check
ifconfig eth10

mkdir -p /opt/vnic

cat <<EOF > /opt/vnic/sas-vnic.service
[Unit]
Description=Setup a virtual NIC and assign a static IP address
Before=kubelet.service docker.service
After=network.target network-online.target

[Service]
Type=oneshot
ExecStart=/opt/vnic/mk_vnic.sh

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /opt/vnic/mk_vnic.sh
#!/bin/sh
# define virtual NIC and start it
modprobe dummy
ip link add dummy0 type dummy
ip link set name eth10 dev dummy0
ip addr add 192.168.100.199/24 brd + dev eth10
ifconfig eth10 up
EOF

chmod a+x /opt/vnic/mk_vnic.sh
systemctl enable /opt/vnic/sas-vnic.service
#systemctl start /opt/vnic/sas-vnic.service
#systemctl status /opt/vnic/sas-vnic.service
```

## Set up NFS server

```shell

yum install -y nfs-utils
systemctl enable nfs-server.service
systemctl start nfs-server.service

mkdir /nfsshare
chown -R nobody: /nfsshare
#sudo chown nfsnobody /nfsshare

systemctl restart nfs-utils.service

vi /etc/exports
cat /etc/exports
/nfsshare        *(rw,async,no_subtree_check,no_root_squash)
#/nfsshare        *(rw,async,no_subtree_check,no_root_squash,nofail,nodiratime)
exportfs -rav
exportfs -s

#sudo firewall-cmd --permanent --add-service=nfs
#sudo firewall-cmd --permanent --add-service=rpc-bind
#sudo firewall-cmd --permanent --add-service=mountd
#sudo firewall-cmd --reload

showmount -e dach-viya4-k8s

```

```shell
# static network shares for user data
# use your own user account instead of centos
cd /nfsshare
mkdir sasdata
chown martin:martin sasdata
mkdir casdata
chown martin:martin casdata
mkdir pythondata
chown martin:martin pythondata
chmod 777 sasdata/ casdata/ pythondata/
vi /etc/fstab
#add the following line
server.local:/srv/nfs   /nfsshare   nfs    user,noauto    0   0
```
mount -a 

Open /nfsshare in Nautilus File Explorer 


## Set up local PostgreSQL database

Add repository, install database, init db, start & enable service. Make sure that Postgres starts _after_ the virtual NIC service has started.

```shell
dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
rpm -qi pgdg-redhat-repo

dnf module disable postgresql
dnf clean all

dnf -y install postgresql11-server postgresql11
dnf info postgresql11-server postgresql11

/usr/pgsql-11/bin/postgresql-11-setup initdb
systemctl enable --now postgresql-11
systemctl status postgresql-11

# make sure that the postgres service starts AFTER the virtual network service
cat /usr/lib/systemd/system/postgresql-11.service
# add:
# After=network.target sas-vnic.service

systemctl daemon-reload

# check systemd start order (view in browser): systemd-analyze plot > systemd.svg
```

Change the Linux password of `postgres` (database superuser)

```shell
cat << EOF | passwd postgres
lnxsas
lnxsas
EOF
```

Change the internal password of `postgres` as well and add a second database user (used by Viya)

```shell
# run the following commands as the "postgres" user
su - postgres

# change the DB password
psql -d template1 -c "ALTER USER postgres WITH PASSWORD 'lnxsas';"

# enter interactive mode
psql postgres

# set up a new user account named "pgadmin"
CREATE ROLE pgadmin WITH LOGIN SUPERUSER CREATEDB CREATEROLE INHERIT REPLICATION PASSWORD 'lnxsas';

# check
\du+

# exit
\q
```

Modify the PostGres configuration. Make sure that the database process listens on dummy network interface and increase the max connections:

```shell
vi /var/lib/pgsql/11/data/postgresql.conf
# add these lines to "postgresql.conf"
listen_addresses = '192.168.100.199'
max_connections = 1024
```

Allow inbound traffic from local IP address and from pod CIDR

```shell
vi /var/lib/pgsql/11/data/pg_hba.conf
# add lines
host    all             all             192.168.100.199/32      password
host    all             all             10.244.0.0/16           password
```

Restart the database process.

```shell
exit
systemctl restart postgresql-11
```

Test local access

```shell
PGPASSWORD=lnxsas psql --user pgadmin -h 192.168.100.199 -d postgres -c 'SELECT datname FROM pg_database;'
```

Btw: to delete the database generated by Viya if you want to re-do the deployment:

```shell
PGPASSWORD=lnxsas psql --user postgres -h 192.168.100.199 -d postgres -c 'DROP DATABASE "SharedServices";'

# or interactively
su - postgres
psql postgres
\l
DROP DATABASE "SharedServices";
\l
\q
```

## Set up Samba Server

NFS shares often do not map properly from Windows. Set up a Samba server to expose the same shares through the SMB protocol.

```shell
yum install samba samba-client -y
systemctl start smb.service
systemctl start nmb.service
systemctl enable smb.service
systemctl enable nmb.service
```

```shell
mv /etc/samba/smb.conf /etc/samba/smb.conf.org
cat <<EOF > /etc/samba/smb.conf
[smbshare]
path = /nfsshare
    browseable = yes
    read only = no
    force create mode = 0777
    force directory mode = 2777
	force user = martin
	force group = martin
EOF
sudo systemctl restart smb.service
sudo systemctl restart nmb.service
```

Add a samba user (Windows policy prohibits anonymous access)

```shell
useradd viyademo01
smbpasswd -a viyademo01
# Password: lnxsas
smbpasswd -e viyademo01
```
Open Nautilus File Explorer and open smbshare using User viyademo01.

Use this command from DOS

```powershell
#net use Z: \\dach-viya4-k8s\smbshare lnxsas /user:localhost\viyademo01
```

