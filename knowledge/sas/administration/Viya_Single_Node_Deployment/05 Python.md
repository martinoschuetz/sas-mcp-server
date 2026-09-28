[TOC]

# Python (SWAT)



## Deploy JupyterLab pod

See: https://hub.docker.com/r/jupyter/datascience-notebook

Need to create a separate Docker image because we want to pre-install SWAT.

```shell
mkdir jupyter-docker-image
cd jupyter-docker-image/

cat << 'EOF' > Dockerfile
# Start from a core stack version
FROM jupyter/datascience-notebook:python-3.8.6
# Install in the default python3 environment
RUN pip install 'swat'
EOF

docker build --rm -t jupyter/datascience-notebook:python-3.8.6-swat .
docker images | grep swat
```

Deployment descriptor

```yaml
cat << 'EOF' > ~/jupyter-datascience.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: jupyter-datascience-app
  namespace: default
  labels:
    app.kubernetes.io/name: jupyter-datascience-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: jupyter-datascience-app
  template:
    metadata:
      labels:
        app: jupyter-datascience-app
        app.kubernetes.io/name: jupyter-datascience-app
    spec:
      containers:
        - name: jupyter-datascience-app
          image: jupyter/datascience-notebook:python-3.8.6-swat
          command:
            - /bin/bash
            - -c
            - |
              start.sh jupyter lab --LabApp.password_required=False --LabApp.token='' --LabApp.ip='0.0.0.0' --LabApp.allow_root=True --LabApp.base_url='/jupyter'
          volumeMounts:
          - name: shared-volume
            mountPath: /home/jovyan/shared
          ports:
            - name: http
              containerPort: 8888
              protocol: TCP
          resources:
            limits:
              cpu: 1
              memory: 8Gi
            requests:
              cpu: 250m
              memory: 250Mi
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      volumes:
      - name: shared-volume
        persistentVolumeClaim:
          claimName: pvc-nfsshare-python
---
kind: Service
apiVersion: v1
metadata:
  name: jupyter-datascience-app
  namespace: default
  labels:
    app.kubernetes.io/name: jupyter-datascience-app
spec:
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8888
  selector:
    app.kubernetes.io/name: jupyter-datascience-app
  type: ClusterIP
---
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: jupyter-datascience-app
  namespace: default
  labels:
    app.kubernetes.io/name: jupyter-datascience-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /jupyter/$2
    nginx.ingress.kubernetes.io/ssl-redirect: \"false\"
spec:
  rules:
    - host: dach-viya4-k8s
      http:
        paths: 
          - path: /jupyter(/|$)(.*)
            backend:
              serviceName: jupyter-datascience-app
              servicePort: 80
          - path: /jupyter
            backend:
              serviceName: jupyter-datascience-app
              servicePort: 80
EOF

kubectl delete -f ~/jupyter-datascience.yaml
kubectl apply -f ~/jupyter-datascience.yaml
kubectl get deploy,pod,service,ing

echo "Access the web application using: http://dach-viya4-k8s/jupyter"
```

### Test

```python
#!pip install swat

import swat

# slower http/REST connection method
#sess = swat.CAS("controller.sas-cas-server-default.viya4.svc.cluster.local", 8777, "viyademo01", "lnxsas")

# fast binary connection method
sess = swat.CAS("controller.sas-cas-server-default.viya4.svc.cluster.local", 5570, "viyademo01", "lnxsas")
print(sess)

out = sess.serverstatus()
print(out)

sess.terminate()
```

