[TOC]

# Monitoring and Logging

*Note*: used Loki instead of Kibana.



## Prepare & download repo

```shell
mkdir ~/ops4viya
cd ~/ops4viya

git clone https://github.com/sassoftware/viya4-monitoring-kubernetes.git
```



## Prepare customizations

```shell
cd ~/ops4viya/
mkdir site-config-monitoring
export USER_DIR=/home/centos/ops4viya/site-config-monitoring
export INGRESS_FQDN=dach-viya4-k8s

##################################################################
# switch monitoring components from NodePort to path based ingress
mkdir $USER_DIR/monitoring
cp /home/centos/ops4viya/viya4-monitoring-kubernetes/samples/ingress/monitoring/user-values-prom-path.yaml $USER_DIR/monitoring/user-values-prom-operator.yaml
cp /home/centos/ops4viya/viya4-monitoring-kubernetes/monitoring/user.env $USER_DIR/monitoring/user.env

# replace all host.mycluster.example.com with $INGRESS_FQDN hostname
sed -i s/host.mycluster.example.com/$INGRESS_FQDN/g $USER_DIR/monitoring/user-values-prom-operator.yaml
# comment out the TLS sections
sed -i '/tls\:/,+3 s/^/#/' $USER_DIR/monitoring/user-values-prom-operator.yaml
# set Grafana password
sed -i s/\#\ GRAFANA\_ADMIN\_PASSWORD\=yourPasswordHere/GRAFANA\_ADMIN\_PASSWORD\=lnxsas/g $USER_DIR/monitoring/user.env

##################################################################
# switch logging components from NodePort to path based ingress
mkdir $USER_DIR/logging
cp /home/centos/ops4viya/viya4-monitoring-kubernetes/samples/ingress/logging/user-values-elasticsearch-path.yaml $USER_DIR/logging/user-values-elasticsearch-open.yaml
cp /home/centos/ops4viya/viya4-monitoring-kubernetes/logging/user.env $USER_DIR/logging/user.env

# replace all host.mycluster.example.com with $INGRESS_FQDN hostname
sed -i s/host.mycluster.example.com/$INGRESS_FQDN/g $USER_DIR/logging/user-values-elasticsearch-open.yaml
# set Kibana password
sed -i s/\#\ ES\_ADMIN\_PASSWD\=yourPasswordHere/ES\_ADMIN\_PASSWD\=lnxsas/g $USER_DIR/logging/user.env
# make sure the node is found
sed -i s/\#\ NODE\_NAME\=mynode\.example\.com/NODE\_NAME\=$INGRESS_FQDN/g $USER_DIR/logging/user.env
```

Manual changes required for Kibana: $USER_DIR/logging/user-values-elasticsearch-open.yaml. Ingress section should look like this:

```yaml
  ingress:
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/affinity: "cookie"
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/configuration-snippet: |
        rewrite (?i)/kibana/(.*) /$1 break;
        rewrite (?i)/kibana$ / break;
      nginx.ingress.kubernetes.io/rewrite-target: /kibana/$2

    enabled: true
    hosts:
    - dach-viya4-k8s
    path: /kibana(/|$)(.*)
```

Note: this does not fully help - the path gets lost. Need to correct this post-deployment.



## Deploy Kibana and Grafana

```shell
cd ~/ops4viya

viya4-monitoring-kubernetes/monitoring/bin/deploy_monitoring_cluster.sh
VIYA_NS=viya4 viya4-monitoring-kubernetes/monitoring/bin/deploy_monitoring_viya.sh

viya4-monitoring-kubernetes/logging/bin/deploy_logging_open.sh
```

The Kibana ingress path component is plain wrong, correct it:

```
kubectl get ing v4m-es-kibana -o json -n logging \
 | jq '(.spec.rules[].http.paths[].path |= "/kibana(/|$)(.*)")' \
 | kubectl apply -f -
```



## Deploy Loki (lightweight log aggregation for Grafana)

```shell
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki --namespace=monitoring grafana/loki
helm upgrade --install promtail grafana/promtail --namespace=monitoring --set "loki.serviceName=loki"
```

(In Grafana: add "Loki" datasource, using http://loki:3100, then go to "Explore", select "Loki", filter on {namespace="viya4"})