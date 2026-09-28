[TOC]

# Boot Monitor



## Prepare Python environment

```shell
sudo yum install python-pip -y
sudo pip install --upgrade pip
sudo pip install zipp configparser python-gitlab virtualenv

mkdir /opt/bootmon
chown centos:centos /opt/bootmon/
cd /opt/bootmon
python -m virtualenv venv

source venv/bin/activate
pip install gunicorn Flask pyyaml kubernetes gitpython gitlab
pip install --upgrade python-gitlab
```

### Manually launch app (using internal flask server)

```shell
export FLASK_DEBUG=1
cd /opt/bootmon
source venv/bin/activate
python app/main.py 
```

### Launch as service (using gunicorn)

```shell
cat <<EOF > /etc/systemd/system/bootmon.service
[Unit]
Description=BootMon web application
After=multi-user.target

[Service]
User=centos
Type=idle
WorkingDirectory=/opt/bootmon/app
ExecStart=/opt/bootmon/venv/bin/gunicorn --bind 0.0.0.0:8083 main:app

[Install]
WantedBy=multi-user.target
EOF

systemctl enable bootmon
systemctl start bootmon
```

```shell
sudo systemctl restart bootmon
```



## Commit changes to Git

```shell
echo "10.24.8.146    gitlab.sas.com" >> /etc/hosts
```

```shell
cd /opt/bootmon
git add .
git commit -m "."
git push origin master
```

