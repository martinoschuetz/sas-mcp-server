# Machine Preparation

Add virtual NIC IP address to Linux `/etc/hosts`

```shell
# sudo vi /etc/hosts
192.168.100.199  dach-viya4-k8s
```
## System Update

```shell
sudo hostnamectl --static set-hostname dach-viya4-k8s
sudo hostnamectl --transient set-hostname dach-viya4-k8s

timedatectl set-timezone UTC

#sudo yum install epel-release -y
sudo apt update
sudo apt upgrade
sudo apt install -y mlocate vim ufw wget git socat htop jq nfs-kernel-server conntrack zip unzip htop tmux mailutils at
sudo updatedb
sudo systemctl enable --now atd.service

sudo apt update
```

### Disable SELinux

```shell
# Set SELinux in permissive mode (effectively disabling it)
#sudo setenforce 0
#sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/ config
```

## Add Docker (19.03)

```shell
# https://docs.docker.com/engine/install/ubuntu/
# 
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

 sudo apt-get update
 sudo apt-get install docker-ce docker-ce-cli containerd.io

sudo docker run hello
sudo docker system prune -f
sudo docker image rm

sudo groupadd -f docker
# Replace centos with your user name
sudo usermod -aG docker centos

sudo systemctl enable docker
sudo systemctl start docker

sudo su -
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

sudo systemctl restart docker
```



## Set up virtual NIC to ensure stable IP address

```shell
modprobe dummy

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

ip link set name eth10 dev dummy0
ip addr add 192.168.100.199/24 brd + dev eth10

ifconfig eth10 up
EOF

chmod a+x /opt/vnic/mk_vnic.sh
systemctl enable /opt/vnic/sas-vnic.service
```



## Set up NFS server

```shell
sudo mkdir /nfsshare
sudo chown nfsnobody: /nfsshare

sudo yum install -y nfs-utils
sudo systemctl enable nfs-server.service
sudo systemctl start nfs-server.service

sudo vi /etc/exports
cat /etc/exports
/nfsshare        *(rw,async,no_subtree_check,no_root_squash,nofail,nodiratime)
sudo exportfs -ra

sudo showmount -e dach-viya4-k8s
```

```shell
# static network shares for user data
cd /nfsshare
sudo mkdir sasdata
sudo chown centos:centos sasdata
sudo mkdir casdata
sudo chown centos:centos casdata
sudo mkdir pythondata
sudo chown centos:centos pythondata
chmod 777 sasdata/ casdata/ pythondata/
```

Use from Windows Explorer:

```
\\dach-viya4-k8s\nfsshare\sasdata
```



## Set up local PostgreSQL database

Add repository, install database, init db, start & enable service. Make sure that Postgres starts _after_ the virtual NIC service has started.

```shell
rpm -Uvh https://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum -y install postgresql11-server postgresql11 postgresql11-contrib

/usr/pgsql-11/bin/postgresql-11-setup initdb
systemctl start postgresql-11 && systemctl enable postgresql-11

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
sudo yum install samba samba-client -y
sudo systemctl start smb.service
sudo systemctl start nmb.service
sudo systemctl enable smb.service
sudo systemctl enable nmb.service
```

```shell
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.org
cat <<EOF > /etc/samba/smb.conf
[smbshare]
path = /nfsshare
    browseable = yes
    read only = no
    force create mode = 0777
    force directory mode = 2777
	force user = centos
	force group = centos
EOF
sudo systemctl restart smb.service
sudo systemctl restart nmb.service
```

Add a samba user (Windows policy prohibits anonymous access)

```shell
smbpasswd -a viyademo01
# Password: lnxsas
smbpasswd -e viyademo01
```

Use this command from DOS

```powershell
net use Z: \\dach-viya4-k8s\smbshare lnxsas /user:localhost\viyademo01
```

