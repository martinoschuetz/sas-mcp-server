[TOC]

# PyMAS configuration



## Prepare PV and PVC for Python runtime volume

Create PV and PVC before deployment.

```yaml
cat << EOF > ~/sas-pymas-pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-pymas
  namespace: viya4
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.100.199
    path: "/nfsshare/pymas-python"
  claimRef:
    namespace: viya4
    name: pvc-pymas
  storageClassName: managed-nfs-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-pymas
  namespace: viya4
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: managed-nfs-storage
  resources:
    requests:
      storage: 5Gi
EOF
```

Submit and check

```shell
kubectl apply -f ~/sas-pymas-pv-pvc.yaml

# check
kubectl get sc,pv,pvc
```



## Prepare and run the provisioning job

```shell
cat << 'EOF' > ~/install-python-3.8.6.sh
#!/bin/bash
set -e

# get input for installation target or use default
if [ $# -eq 0 ]; then
  export DIR="$(pwd)/python"
else
  export DIR=$1
fi

# check that path is absolute
case $DIR in
  /*) echo "Installation target dir: $DIR" ;;
  *)  echo "Path to installation target is not absolute: $DIR"
      exit 1 
      ;;
esac

# prepare environment
yum install -y wget zlib-devel openssl openssl-devel \
  libffi-devel gdbm-devel tk-devel xz-devel sqlite-devel \
  readline-devel bzip2-devel ncurses-devel libpcap-devel patch
yum groupinstall -y 'Development Tools'
yum update -y
            
# download and unzip installer
wget -q https://www.python.org/ftp/python/3.8.6/Python-3.8.6.tgz
echo "BEGIN Unzipping installer"
tar -xzf Python-*.tgz
echo "DONE Unzipping installer"

# install python
mkdir -p $DIR
cd Python-*
./configure --prefix=$DIR && make && make altinstall

# install required packages
cd $DIR/bin
./python3.8 -m pip install -r /scripts/requirements.txt
EOF

cat << 'EOF' > ~/requirements.txt
numpy
pandas
xgboost
scipy
joblib
patsy
python-dateutil
pytz
scikit-learn
six
statsmodels
readline
EOF
```

```shell
# create as configmap
kubectl delete configmap python-builder-script-3.8.6 -n viya4
kubectl create configmap python-builder-script-3.8.6 -n viya4 \
    --from-file=install-python-3.8.6.sh \
    --from-file=requirements.txt

# check
kubectl describe configmap python-builder-script-3.8.6 -n viya4
```

Install python using a centos pod.

```yaml
cat << EOF > ~/python-pymas-builder-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: python-pymas-builder-job
  namespace: viya4
spec:
  template:
    spec:
      containers:
      - image: centos:centos7
        name: python-builder-job
        command: ["/bin/sh", "-c"]
        args:
          - /scripts/install-python-3.8.6.sh /python/python-3.8.6
        volumeMounts:
        - name: host-volume
          mountPath: /python
        - name: install-script
          mountPath: /scripts
      restartPolicy: Never
      volumes:
      - name: host-volume
        persistentVolumeClaim:
          claimName: pvc-pymas
      - name: install-script
        configMap:
          name: python-builder-script-3.8.6          
          defaultMode: 0755
EOF
```

```shell
kubectl apply -f ~/python-pymas-builder-job.yaml
```

Follow the log

```shell
kubectl logs job/python-pymas-builder-job -n viya4 -f
```

Remove the job

```
kubectl delete -f ~/python-pymas-builder-job.yaml
```



