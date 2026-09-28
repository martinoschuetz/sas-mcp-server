[TOC]

# Kubernetes infrastructure

## Kubernetes install

```shell
yum install -y yum-utils device-mapper-persistent-data lvm2

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

echo 'br_netfilter' > /etc/modules-load.d/br_netfilter.conf
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
#sudo yum install -y kubelet-1.18* kubeadm-1.18* kubectl-1.18* --disableexcludes=kubernetes

sudo systemctl enable --now kubelet


systemctl stop firewalld
#sudo kubeadm reset
#firewall-cmd --zone public --list-all
#firewall-cmd --get-active-zones


#https://www.tecmint.com/open-port-for-specific-ip-address-in-firewalld/
firewall-cmd --new-zone=kubectl_access --permanent
firewall-cmd --reload
firewall-cmd --get-zones

firewall-cmd --zone=kubectl_access --add-source=192.168.100.199/24 --permanent
#firewall-cmd --zone=kubectl_access --add-port=6443/tcp --permanent
#firewall-cmd --zone=kubectl_access --add-port=10250/tcp --permanent
#firewall-cmd --zone=internal --add-port=10248/tcp --permanent
#firewall-cmd --zone=public --add-port=5432/tcp --permanent
firewall-cmd --add-port=6443/tcp --permanent
firewall-cmd --add-port=10250/tcp --permanent
firewall-cmd --add-port=10248/tcp --permanent
firewall-cmd --add-port=5432/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=kubectl_access --list-all
# Not sure whether this is necessary
systemctl restart firewalld

# kubernetes requires "swapoff -a"
# Activating "swapon -a" two times crashed cenots
# Use "fail-swap-on=false" work with swap on.
# Parameter documentation (https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
# Recommended version via config file (https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/)
# First try with depreceated version (https://github.com/kubernetes/kubeadm/issues/610)  

systemctl stop firewalld
kubeadm reset 
echo 'Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"' >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl restart kubelet

# Paramter "--ignore-preflight-errors Swap" required
kubeadm init --ignore-preflight-errors Swap --apiserver-advertise-address=192.168.100.199 --pod-network-cidr=10.244.0.0/16

#kubectl get nodes

# increase number of pods
vi /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# add: ExecStart=... --max-pods=201

systemctl daemon-reload
systemctl restart kubelet
```

### Set up KUBECONFIG

Set up KUBECONFIG. Repeat this for user "centos".

```shell
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

export KUBECONFIG=$HOME/.kube/config
echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bash_profile
```

### Set up k8s networking

```shell
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

systemctl restart kubelet
systemctl status kubelet

kubectl get nodes
```

### Remove master taint and label from node

```shell
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl label nodes --all node-role.kubernetes.io/master-
```

## Tooling

### Lens

```shell
export KUBECONFIG=~/.kube/config
cat $KUBECONFIG
# copy & paste to Windows, then replace IP address in config with "dach-viya4-k8s"
```

Install Lens on Linux from downloaded rpm
```
#sudo yum install epel-release
#sudo yum install snapd
#sudo systemctl enable --now snapd.socket
#sudo ln -s /var/lib/snapd/snap /snap
#sudo snap install kontena-lens --classic
´´´
Add Cluster as normal user from ~/.kube/config and add metrics under Properties.

### Helm

```shell
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version

helm repo add stable https://charts.helm.sh/stable
helm search repo stable
helm repo update

# this is empty for now (but should not return an error)
helm list
```

### kustomize

```shell
curl -O -s -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.7.0/kustomize_v3.7.0_linux_amd64.tar.gz

tar xvzf kustomize_*_linux_amd64.tar.gz
mv kustomize /usr/local/bin/

kustomize version

rm -f kustomize_*_linux_amd64.tar.gz
```

### k9s

```shell
wget https://github.com/derailed/k9s/releases/download/v0.24.2/k9s_Linux_x86_64.tar.gz
tar xvzf k9s_Linux_x86_64.tar.gz

mv k9s /usr/local/bin/

rm -f k9s_Linux_x86_64.tar.gz
```



## Kubernetes packages

### nginx - ingress controller

Deploy ingress controller. Note that there is no external load balancer, so we instruct nginx to use the host network.

See: https://kubernetes.github.io/ingress-nginx/

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# we need a specific version
helm search repo ingress-nginx --versions | grep 3.9.0

# make nginx use host network (uses port 80 and 443)
helm install ingress-nginx ingress-nginx/ingress-nginx --version 3.9.0 \
    --set controller.hostNetwork=true,controller.service.type="",controller.kind=DaemonSet

# check
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- /nginx-ingress-controller --version

# returns 404 - default backend, give it some time 
curl http://dach-viya4-k8s
```

#### Test

```shell
cat << EOF > ~/test-http-echoserver.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: e2e
spec:
  replicas: 1
  selector:
    matchLabels:
      app: e2e
  template:
    metadata:
      name: e2e
      labels:
        app: e2e
    spec:
      containers:
      - name: http-echo
        image: gcr.io/kubernetes-e2e-test-images/echoserver:2.2
        ports:
        - containerPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: e2e-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: \"false\"
spec:
  rules:
  - host: $(hostname)
    http:
      paths:
      - path: /e2e-test
        backend:
          serviceName: e2e-svc
          servicePort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: e2e-svc
spec:
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: e2e
EOF

kubectl apply -f  ~/test-http-echoserver.yaml
kubectl get all

echo "Access the web application using: http://dach-viya4-k8s/e2e-test"
```



### nfs - shared storage

We only use NFS for external storage (RWO and RWX). We connect to the NFS server on the Linux host

See: https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner

```shell
# https://blog.exxactcorp.com/deploying-dynamic-nfs-provisioning-in-kubernetes/
cd ~
git clone https://exxsyseng@bitbucket.org/exxsyseng/nfs-provisioning.git
cd ~/nfs-provisioning/

sed -i "s|example.com/||g" class.yaml
sed -i 's|^  name: managed-nfs-storage|&\n  annotations:\n    storageclass.kubernetes.io/is-default-class: "true"|' class.yaml
sed -i "s|example.com/||g" deployment.yaml
sed -i "s|/srv/nfs/kubedata|/nfsshare|g" deployment.yaml
sed -i "s|<<NFS Server IP>>|192.168.100.199|g" deployment.yaml

kubectl apply -f rbac.yaml
kubectl apply -f class.yaml
kubectl apply -f deployment.yaml

kubectl get sc
```

#### Static file shares for SAS, CAS and Python

```yaml
kubectl create ns viya4

cat << EOF > ~/nfs-static-pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfsshare-python
  namespace: default
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.100.199
    path: "/nfsshare/pythondata"
  claimRef:
    namespace: default
    name: pvc-nfsshare-python
  storageClassName: managed-nfs-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfsshare-python
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: managed-nfs-storage
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfsshare-sas
  namespace: viya4
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.100.199
    path: "/nfsshare/sasdata"
  claimRef:
    namespace: viya4
    name: pvc-nfsshare-sas
  storageClassName: managed-nfs-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfsshare-sas
  namespace: viya4
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: managed-nfs-storage
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfsshare-cas
  namespace: viya4
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.100.199
    path: "/nfsshare/casdata"
  claimRef:
    namespace: viya4
    name: pvc-nfsshare-cas
  storageClassName: managed-nfs-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfsshare-cas
  namespace: viya4
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: managed-nfs-storage
  resources:
    requests:
      storage: 20Gi
EOF

kubectl delete -f ~/nfs-static-pv-pvc.yaml
kubectl apply -f ~/nfs-static-pv-pvc.yaml
```

#### Test

```shell
cat << EOF > ~/test-nfs-access.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs-access
  namespace: default
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.100.199
    path: "/nfsshare"
  claimRef:
    namespace: default
    name: pvc-nfs-access
  storageClassName: managed-nfs-storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs-access
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: managed-nfs-storage
  resources:
    requests:
      storage: 1Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: test-nfs-access
  namespace: default
spec:
  template:
    spec:
      containers:
      - image: busybox
        name: test-nfs-access
        command: [ "/bin/sh", "-c", "ls -lisa /mydata" ]
        volumeMounts:
        - name: host-volume
          mountPath: /mydata
      restartPolicy: Never
      volumes:
      - name: host-volume
        persistentVolumeClaim:
          claimName: pvc-nfs-access
EOF

# Launch a job using this volume
kubectl apply -f ~/test-nfs-access.yaml
kubectl get jobs,pv,pvc,sc

kubectl describe persistentvolumeclaim/pvc-nfs-access

# check for errors
kubectl describe pod test-nfs-access

kubectl logs jobs/test-nfs-access
# check for user "1001": ... drwxrwxrwx 2 root root 0 ...

# delete resources
kubectl delete -f ~/test-nfs-access.yaml
```

### cert-manager

```shell
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
```

### openldap

Note: use modified deployment script (download openldap from Git repo)

```shell
tar xvzf /home/martin/deploy-openldap.tgz

cd ./deploy-openldap/

# openldap repo has been deprecated, deploy from Git
git clone https://github.com/helm/charts.git

# replace in ./bin/deploy-openldap.sh
# from: helm install openldap stable/openldap ...
# to:   helm install openldap charts/stable/openldap/ --values charts/stable/openldap/values.yaml ...

./bin/deploy-openldap.sh

# in case something goes wrong
# helm delete openldap -n openldap
```


