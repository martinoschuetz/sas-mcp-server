#!/bin/bash

echo "------------------------------------------------------------------------"
echo "---                                                                  ---"
echo "---     This script runs after a system reboot. It checks the        ---"
echo "---     current state of the kubernetes cluster and scales up        ---"
echo "---     the Viya deployment if the cluster is in <Ready> state.      ---"
echo "---                                                                  ---"
echo "---     Script invocation is controlled in crontab:                  ---"
echo "---       @reboot /opt/bootmon/app/scripts/scaleup-viya.sh           ---"
echo "---                                                                  ---"
echo "------------------------------------------------------------------------"

# Log progress
echo "----------------------------------------------------------------"  > /tmp/scaleup-viya.log
echo "Script starts after system launch at" $(date)                     >> /tmp/scaleup-viya.log
sleep 120

# loop control variables
rc=""
retries=0
sleeptime=5     # 5 seconds
maxretries=60   # 5*60 = 5 minutes

# check services state
echo ""                                                                 >> /tmp/scaleup-viya.log
echo "--- Checking service states ------------------------------------" >> /tmp/scaleup-viya.log
while : ; do
    ST_DOCKER=$(systemctl is-active docker)
    ST_KUBELET=$(systemctl is-active kubelet)
    ST_POSTGRES=$(systemctl is-active postgresql-11)

    echo ""                                                             >> /tmp/scaleup-viya.log
    printf "Docker service is: %s\n" $ST_DOCKER                         >> /tmp/scaleup-viya.log
    printf "Kubelet service is: %s\n" $ST_KUBELET                       >> /tmp/scaleup-viya.log
    printf "PostgreSQL service is: %s\n" $ST_POSTGRES                   >> /tmp/scaleup-viya.log

    if [ "$ST_DOCKER" = "active" ] && [ "$ST_KUBELET" = "active" ] && [ "$ST_POSTGRES" = "active" ]
    then
        echo "All services are active, continuing"                      >> /tmp/scaleup-viya.log
        break
    else
        printf "Waiting for services, sleep and retry ... %s/%s\n" $retries $maxretries >> /tmp/scaleup-viya.log
        retries=$((retries+1))
        sleep $sleeptime
    fi

    if [ $retries -ge $maxretries ]; then
        echo "Max retries reached, giving up at" $(date)                >> /tmp/scaleup-viya.log
        exit 1
    fi
done

# check cluster state
retries=0
echo ""                                                                 >> /tmp/scaleup-viya.log
echo "--- Checking cluster status ------------------------------------" >> /tmp/scaleup-viya.log
while : ; do

    echo ""                                                             >> /tmp/scaleup-viya.log
    kubectl get nodes --kubeconfig=/home/centos/.kube/config            >> /tmp/scaleup-viya.log
    echo ""                                                             >> /tmp/scaleup-viya.log

    rc=$(JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]} {@.type}={@.status};{end}{end}' \
        && kubectl get nodes --kubeconfig=/home/centos/.kube/config -o jsonpath="$JSONPATH" | grep "Ready=True")

    if [ -z "$rc" ]
    then
        echo "Cluster is not yet in <Ready> state"                      >> /tmp/scaleup-viya.log
    else
        echo "Cluster is in <Ready> state, continuing"                  >> /tmp/scaleup-viya.log
        break
    fi
    
    if [ $retries -ge $maxretries ]; then
        echo "Max retries reached, giving up at" $(date)                >> /tmp/scaleup-viya.log
        exit 1
    fi

    printf "Sleep and retry ... %s/%s\n" $retries $maxretries           >> /tmp/scaleup-viya.log
    retries=$((retries+1))
    sleep $sleeptime
done

# intermittent issues with openldap pod getting stuck complaining about
# "error: /run/flannel/subnet.env: no such file or directory"
# assuming race condition, so check for flannel before continuing
retries=0
echo ""                                                                 >> /tmp/scaleup-viya.log
echo "--- Checking state of flannel network --------------------------" >> /tmp/scaleup-viya.log
echo ""                                                                 >> /tmp/scaleup-viya.log
while : ; do

    rc=$(JSONPATH='{range .items[*]}{@.metadata.name}{","}{@.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
        && kubectl get pods -l app=flannel --kubeconfig=/home/centos/.kube/config -n kube-system -o jsonpath="$JSONPATH")

    IFS=, read pod state <<< $rc
    if [ $state == True ]
    then
        echo "flannel pod is in <Running> state, checking subnet.env"   >> /tmp/scaleup-viya.log
        if [ -f "/run/flannel/subnet.env" ]; then
            echo "/run/flannel/subnet.env exists, continuing"           >> /tmp/scaleup-viya.log
            break
        fi
    fi

    if [ $retries -ge $maxretries ]; then
        echo "Max retries reached, giving up at" $(date)                >> /tmp/scaleup-viya.log
        exit 1
    fi

    printf "Sleep and retry ... %s/%s\n" $retries $maxretries           >> /tmp/scaleup-viya.log
    retries=$((retries+1))
    sleep $sleeptime
done

# check openldap pod
retries=0
echo ""                                                                 >> /tmp/scaleup-viya.log
echo "--- Checking state of openldap pod -----------------------------" >> /tmp/scaleup-viya.log
echo ""                                                                 >> /tmp/scaleup-viya.log
while : ; do

    rc=$(JSONPATH='{range .items[*]}{@.metadata.name}{","}{@.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
        && kubectl get pods --kubeconfig=/home/centos/.kube/config -n openldap -o jsonpath="$JSONPATH")
        
    IFS=, read pod state <<< $rc
    if [ $state == True ]
    then
        echo "openldap pod is in <Running> state, continuing"           >> /tmp/scaleup-viya.log
        break
    fi

    if [ $retries -ge $maxretries ]; then
        echo "Max retries reached, giving up at" $(date)                >> /tmp/scaleup-viya.log
        exit 1
    fi

    printf "Sleep and retry ... %s/%s\n" $retries $maxretries           >> /tmp/scaleup-viya.log
    retries=$((retries+1))
    sleep $sleeptime
done

# run the scale-up procedure
echo ""                                                                 >> /tmp/scaleup-viya.log
echo "--- Scaling Viya pods ------------------------------------------" >> /tmp/scaleup-viya.log
echo ""                                                                 >> /tmp/scaleup-viya.log
su - centos <<'EOSU'
cd ~/viya4;
kubectl apply -f site.yaml --kubeconfig=/home/centos/.kube/config
EOSU

echo "Sleeping for 30 minutes before final check:" $(date)              >> /tmp/scaleup-viya.log
sleep 30m

echo ""                                                                 >> /tmp/scaleup-viya.log
echo "Bouncing any failed pods:" $(date)                                >> /tmp/scaleup-viya.log
su - centos <<'EOSU'
for tuple in $(JSONPATH='{range .items[*]}{@.metadata.name}{","}{@.status.conditions[?(@.type=="Ready")].status}{","}{@.status.conditions[?(@.type=="Ready")].reason}{"\n"}{end}' \
        && kubectl get pods --kubeconfig=/home/centos/.kube/config -n viya4 -o jsonpath="$JSONPATH"); do
    IFS=, read pod state reason <<< $tuple
    if [ $state == False ] && [ $reason == ContainersNotReady ]
    then
        echo "Found pod in ContainersNotReady state:" $pod              >> /tmp/scaleup-viya.log
        kubectl delete pod $pod -n viya4 \
            --kubeconfig=/home/centos/.kube/config                      >> /tmp/scaleup-viya.log
    fi
done
EOSU

echo ""                                                                 >> /tmp/scaleup-viya.log
echo "Script terminates at" $(date)                                     >> /tmp/scaleup-viya.log
exit 0

