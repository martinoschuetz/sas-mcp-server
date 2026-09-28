[TOC]

# Viya Deployment



## Prerequisites

### Create viya4 namespace

```
cat << 'EOF' > ~/viya4-namespace.yaml
kind: Namespace
apiVersion: v1
metadata:
  name: viya4
  labels:
    name: viya4
EOF

kubectl apply -f ~/viya4-namespace.yaml
```

### Deployment Folders

```shell
mkdir ~/viya4
cd ~/viya4

# will contain customizations
mkdir -p site-config/patches
mkdir -p site-config/resources

cp ../deploy-openldap/etc/openldap/sitedefault.yml .
```

### Viya Orders CLI

```shell
cd ~

wget https://golang.org/dl/go1.15.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.15.2.linux-amd64.tar.gz
rm -f go1.15.2.linux-amd64.tar.gz
# add path to ~/.bash_profile
# PATH=$PATH:$HOME/.local/bin:$HOME/bin:/usr/local/go/bin
. ~/.bash_profile

# check
go version

# download CLI (githje)
git clone https://github.com/sassoftware/viya4-orders-cli.git

cat << EOF > ~/.viya4-orders-cli.json
{
  "clientCredentialsId": "$(echo -n "3BB3imLLA0P5wVPxAJlG9XhGESXM35A6" | base64)",
  "clientCredentialsSecret": "$(echo -n "sTDqYR2b6epqFjSX" | base64)"
}
EOF

cd ~/viya4-orders-cli

# VAVS only test order
go run main.go dep 09TR81 stable 2020.1.1 -p ~ \
    -n SASViyaV4_09TR81_2020.1.1_stable \
    --config ~/.viya4-orders-cli.json

# Machine Learning order
go run main.go dep 09V3WB stable 2020.1.1 -p ~ \
    -n SASViyaV4_09V3WB_2020.1.1_stable \
    --config ~/.viya4-orders-cli.json
```

```
cd viya4
tar xvzf ~/SASViyaV4_09TR81_2020.1.1_stable.tgz
```

### Check access to external PostgreSQL database

```shell
cat << EOF > ~/test-pg-access-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: test-pg-access
  namespace: default
spec:
  template:
    spec:
      containers:
      - image: postgres:11
        name: test-pg-access
        command: [ "/bin/sh", "-c", "PGPASSWORD=lnxsas psql --user pgadmin -h 192.168.100.199 -d postgres -c 'SELECT datname FROM pg_database;'" ]
      restartPolicy: Never
EOF

# launch
kubectl apply -f ~/test-pg-access-job.yaml

# check
kubectl wait --for=condition=complete jobs/test-pg-access
kubectl logs jobs/test-pg-access

# delete
kubectl delete -f ~/test-pg-access-job.yaml
```



## Patches

### Storage related

```yaml
cat << 'EOF' > site-config/patches/storage-class.yaml
kind: PersistentStorageClass
metadata:
  name: wildcard
spec:
  storageClassName: managed-nfs-storage
EOF
```

```yaml
cat << 'EOF' > site-config/patches/backup-storage.yaml
kind: PersistentVolumeClaim
metadata:
  name: sas-common-backup-data
spec:
  resources:
    requests:
      storage: 16Gi
EOF
```

```yaml
cat << 'EOF' > site-config/patches/mas-astore-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sas-microanalytic-score-astores
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  resources:
    requests:
      storage: 16Gi
  storageClassName: managed-nfs-storage
EOF
```

```yaml
cat << EOF > site-config/patches/sas-nfsshare-mount.yaml
---
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: compute-server-add-nfsshare-volume
patch: |-
  - op: add
    path: /template/spec/volumes/-
    value:
      name: nfsshare-volume-sas
      persistentVolumeClaim:
        claimName: pvc-nfsshare-sas
  - op: add
    path: /template/spec/containers/0/volumeMounts/-
    value:
        name: nfsshare-volume-sas
        mountPath: /sasdata
  - op: add
    path: /template/spec/volumes/-
    value:
      name: nfsshare-volume-cas
      persistentVolumeClaim:
        claimName: pvc-nfsshare-cas
  - op: add
    path: /template/spec/containers/0/volumeMounts/-
    value:
      name: nfsshare-volume-cas
      mountPath: /casdata
target:
  name: sas-compute-job-config
  version: v1
  kind: PodTemplate
EOF
```

```yaml
cat << EOF > site-config/patches/batch-nfsshare-mount.yaml
---
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: batch-server-add-nfsshare-volume
patch: |-
  - op: add
    path: /template/spec/volumes/-
    value:
      name: nfsshare-volume-sas
      persistentVolumeClaim:
        claimName: pvc-nfsshare-sas
  - op: add
    path: /template/spec/containers/0/volumeMounts/-
    value:
        name: nfsshare-volume-sas
        mountPath: /sasdata
  - op: add
    path: /template/spec/volumes/-
    value:
      name: nfsshare-volume-cas
      persistentVolumeClaim:
        claimName: pvc-nfsshare-cas
  - op: add
    path: /template/spec/containers/0/volumeMounts/-
    value:
      name: nfsshare-volume-cas
      mountPath: /casdata
target:
  name: sas-batch-pod-template
  version: v1
  kind: PodTemplate
EOF
```

```yaml
cat << EOF > site-config/patches/cas-nfsshare-mount.yaml
---
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: cas-add-nfsshare-volume
patch: |-
  - op: add
    path: /spec/controllerTemplate/spec/volumes/-
    value:
      name: nfsshare-volume-cas
      persistentVolumeClaim:
        claimName: pvc-nfsshare-cas
  - op: add
    path: /spec/controllerTemplate/spec/containers/0/volumeMounts/-
    value:
      name: nfsshare-volume-cas
      mountPath: /casdata
  - op: add
    path: /spec/controllerTemplate/spec/volumes/-
    value:
      name: nfsshare-volume-sas
      persistentVolumeClaim:
        claimName: pvc-nfsshare-sas
  - op: add
    path: /spec/controllerTemplate/spec/containers/0/volumeMounts/-
    value:
      name: nfsshare-volume-sas
      mountPath: /sasdata
target:
  group: viya.sas.com
  kind: CASDeployment
  name: .*
  version: v1alpha1
EOF
```

### Adding hosts entry

```yaml
cat << EOF > site-config/patches/sas-hosts-entry.yaml
---
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: compute-server-add-hosts-entry
patch: |-
  - op: add
    path: /template/spec/hostAliases/-
    value:
      ip: "192.168.100.199"
      hostnames:
      - "dach-viya4-k8s"
target:
  name: sas-compute-job-config
  version: v1
  kind: PodTemplate
EOF
```

```yaml
cat << EOF > site-config/patches/batch-hosts-entry.yaml
---
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: batch-server-add-hosts-entry
patch: |-
  - op: add
    path: /template/spec/hostAliases/-
    value:
      ip: "192.168.100.199"
      hostnames:
      - "dach-viya4-k8s"
target:
  name: sas-batch-pod-template
  version: v1
  kind: PodTemplate
EOF
```

### PyMAS specific steps

Make sure that the needed PV and PVC for the shared storage is available.

```shell
cd ~/viya4
mkdir -p site-config/sas-open-source-config/python

cp sas-bases/examples/sas-open-source-config/python/*.yaml site-config/sas-open-source-config/python
chmod 644 site-config/sas-open-source-config/python/*

sed -e '/SAS_EXTLANG_SETTINGS/ s/^#*/#/' -i site-config/sas-open-source-config/python/kustomization.yaml
sed -e '/SAS_EXT_LLP_PYTHON/ s/^#*/#/' -i site-config/sas-open-source-config/python/kustomization.yaml

sed -i "s|/{{ PYTHON-EXE-DIR }}|/python-3.8.6/bin|" site-config/sas-open-source-config/python/kustomization.yaml
sed -i "s|/{{ PYTHON-EXECUTABLE }}|/python3.8|" site-config/sas-open-source-config/python/kustomization.yaml

sed -i "s|{ name: python-volume, {{ VOLUME-ATTRIBUTES }} }|\n      name: python-volume\n      persistentVolumeClaim:\n        claimName: pvc-pymas|" site-config/sas-open-source-config/python/python-transformer.yaml
```

### Other patches

```yaml
# create token (cr.sas.com/tokens)
TOKENUSERNAME=p-F5ZV8X-fugKk
TOKENPASSWORD=lxavz-g10EfF9ZoolGdt-Fz7E_1--_GGhbbvmoyr

kubectl create secret docker-registry test \
  --docker-server=cr.sas.com \
  --docker-username=$TOKENUSERNAME \
  --docker-password=$TOKENPASSWORD \
  --dry-run=client \
  --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode > site-config/resources/cr_sas_com_access.json
```

```yaml
cat << 'EOF' > site-config/patches/cas-limits.yaml
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: cas-manage-cpu-and-memory
patch: |-
  - op: add
    path: /spec/controllerTemplate/spec/containers/0/resources/limits
    value:
      memory: 32Gi
  - op: replace
    path: /spec/controllerTemplate/spec/containers/0/resources/requests/memory
    value:
      4Gi
  - op: add
    path: /spec/controllerTemplate/spec/containers/0/resources/limits/cpu
    value:
      4
  - op: replace
    path: /spec/controllerTemplate/spec/containers/0/resources/requests/cpu
    value:
      1
target:
  group: viya.sas.com
  kind: CASDeployment
  name: .*
  version: v1alpha1
EOF
```

### kustomization.yaml

```yaml
cat << EOF > kustomization.yaml
namespace: viya4

resources:
- sas-bases/base
- sas-bases/overlays/network/ingress
- sas-bases/overlays/cas-server
- site-config/patches/mas-astore-pvc.yaml
- site-config/sas-open-source-config/python

configurations:
- sas-bases/overlays/required/kustomizeconfig.yaml

transformers:
- sas-bases/overlays/external-postgres/external-postgres-transformer.yaml
- site-config/patches/cas-limits.yaml
- site-config/patches/sas-nfsshare-mount.yaml
- site-config/patches/cas-nfsshare-mount.yaml
- site-config/patches/batch-nfsshare-mount.yaml
- site-config/patches/sas-hosts-entry.yaml
- site-config/patches/batch-hosts-entry.yaml
- sas-bases/overlays/sas-microanalytic-score/astores/astores-transformer.yaml
- site-config/sas-open-source-config/python/python-transformer.yaml
- sas-bases/overlays/required/transformers.yaml

patches:
- path: site-config/patches/storage-class.yaml
  target:
    kind: PersistentVolumeClaim
- path: site-config/patches/backup-storage.yaml
  target:
    kind: PersistentVolumeClaim
    annotationSelector: sas.com/component-name in (sas-backup-job)

secretGenerator:
- name: sas-image-pull-secrets
  behavior: replace
  type: kubernetes.io/dockerconfigjson
  files:
  - .dockerconfigjson=site-config/resources/cr_sas_com_access.json
- name: postgres-sas-user
  literals:
  - username=pgadmin
  - password=lnxsas

configMapGenerator:
- name: sas-consul-config
  behavior: merge
  files:
  - SITEDEFAULT_CONF=sitedefault.yml
- name: ingress-input
  behavior: merge
  literals:
  - INGRESS_HOST=$(hostname)
- name: sas-shared-config
  behavior: merge
  literals:
  - SAS_SERVICES_URL=http://$(hostname):80
- name: sas-postgres-config
  behavior: merge
  literals:
  - DATABASE_HOST=192.168.100.199
  - DATABASE_PORT=5432
  - DATABASE_SSL_ENABLED="false"
  - DATABASE_NAME=SharedServices
  - EXTERNAL_DATABASE="true"
  - SAS_DATABASE_DATABASESERVERNAME="postgres"
EOF
```



## Build and Deploy

### Scale up / down

```shell
# prepare scale down/up
cd viya4

mkdir scaleup
mkdir scaledown1
mkdir scaledown2

cp kustomization.yaml scaleup
cp kustomization.yaml scaledown1
cp kustomization.yaml scaledown2

# regular + scaleup
cp scaleup/kustomization.yaml .
kustomize build -o site.yaml

# prepare scaledown
sed -i 's|^- sas-bases/overlays/required/transformers.yaml|&\n- sas-bases/overlays/scaling/zero-scale/phase-0-transformer.yaml|' scaledown1/kustomization.yaml
cp scaledown1/kustomization.yaml .
kustomize build -o site-scaledown1.yaml

sed -i 's|^- sas-bases/overlays/required/transformers.yaml|&\n- sas-bases/overlays/scaling/zero-scale/phase-0-transformer.yaml\n- sas-bases/overlays/scaling/zero-scale/phase-1-transformer.yaml|' scaledown2/kustomization.yaml
cp scaledown2/kustomization.yaml .
kustomize build -o site-scaledown2.yaml

# perform scale down
kubectl apply -f site-scaledown1.yaml
kubectl -n viya4 wait --for=delete -l casoperator.sas.com/server=default pods
kubectl -n viya4 delete espserver --all
kubectl apply -f site-scaledown2.yaml

# perform scale up
kustomize build -o site.yaml
```

### Regular build

```shell
kustomize build -o site.yaml

kubectl apply --selector="sas.com/admin=cluster-wide" -f site.yaml
kubectl apply --selector="sas.com/admin=cluster-wide" -f site.yaml
kubectl apply --selector="sas.com/admin=cluster-local" -f site.yaml --prune
kubectl apply --selector="sas.com/admin=namespace" -f site.yaml --prune
```



## Post configuration steps

### Prepare the SAS Viya CLI

```shell
kubectl -n viya4 cp $(kubectl -n viya4 get pod | grep "sas-logon-app" | awk -F" " '{print $1}'):/opt/sas/viya/config/etc/SASSecurityCertificateFramework/cacerts/trustedcerts.pem ~/viya4/trustedcerts.pem

echo "export SSL_CERT_FILE=~/viya4/trustedcerts.pem" >> ~/.bash_profile
export SSL_CERT_FILE=~/viya4/trustedcerts.pem

cd /usr/local/
sudo tar xvzf ~/sas-viya-cli-*-linux-amd64.tgz

sas-viya plugins list-repos
sas-viya plugins list-repo-plugins

sas-viya plugins install --repo sas audit
sas-viya plugins install --repo sas authorization
sas-viya plugins install --repo sas batch
sas-viya plugins install --repo sas cas
sas-viya plugins install --repo sas compute
sas-viya plugins install --repo sas configuration
sas-viya plugins install --repo sas dcmtransfer
sas-viya plugins install --repo sas devices
sas-viya plugins install --repo sas folders
sas-viya plugins install --repo sas fonts
sas-viya plugins install --repo sas healthcheck
sas-viya plugins install --repo sas identities
sas-viya plugins install --repo sas job
sas-viya plugins install --repo sas licenses
sas-viya plugins install --repo sas models
sas-viya plugins install --repo sas oauth
sas-viya plugins install --repo sas qkbs
sas-viya plugins install --repo sas reports
sas-viya plugins install --repo sas rtdmobjectmigration
sas-viya plugins install --repo sas scoreexecution
sas-viya plugins install --repo sas transfer
```

### Add fileshare to allowlist

Add /casdata to the CAS allowlist. Create profile, login, add fileshare to allowlist (note: requires viyademo01 to be a SAS/CAS administrator)

```shell
sas-viya profile init
#Service Endpoint> http://dach-viya4-k8s
#Output type (text|json|fulljson)> text
#Enable ANSI colored output (y/n)?> n

sas-viya auth login --user viyademo01 --password lnxsas

# Check
sas-viya cas servers list --all

# add to allowlist
sas-viya cas servers paths-list add-paths --server cas-shared-default --path /casdata
sas-viya cas servers paths-list list --server cas-shared-default
```

### Add Workflow user

```
Add "sas.workflow.client.sasmodelmanager" configuration to workflow.service and enter "viyademo01" as value.
```

### Create CASHostAccountRequired group

```
Add CASHostAccountRequired custom group and add viyademo01 to it. Required by SWAT and PyMAS.
```

### Enable Git Integration in SAS Studio

```
In EV -> SAS Studio -> set sas.studio.showServerFiles to "True"
```


