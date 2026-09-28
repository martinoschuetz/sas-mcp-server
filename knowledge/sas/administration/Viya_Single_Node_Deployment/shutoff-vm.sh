#!/bin/bash

# Guard against submitting commands twice
PIDFILE=/tmp/shutoff-vm.pid
if [ -f $PIDFILE ]
then
    PID=$(cat $PIDFILE)
    ps -p $PID > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        # bail out
        echo "Process already running"
        exit 1
    else
        # pid not found (zombie?), recreate
        echo $$ > $PIDFILE
        if [ $? -ne 0 ]
        then
            echo "Could not create PID file"
            exit 1
        fi
    fi
else
    # create a new pid file and continue
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
        echo "Could not create PID file"
        exit 1
    fi
fi

echo "<b>------------------------------------------------------------------------</b>"  > /tmp/shutoff-vm.log
echo "<b>---                                                                  ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---     This script will                                             ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---                                                                  ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---       1) scale down all Viya pods to zero instances              ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---       2) stop the Kubernetes and Docker services                 ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---       3) shut down the virtual machine                           ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---                                                                  ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---     Use the <a href="http://go.sas.com/aws" target="_blank">AWS console</a> to restart this machine.                 ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---                                                                  ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---     Reload this page to watch for progress.                      ---</b>" >> /tmp/shutoff-vm.log
echo "<b>---                                                                  ---</b>" >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log

echo ""                                                                                >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log
echo "<b>---     1) Scaling down Viya services                                ---</b>" >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log
cd ~/viya4
kubectl apply -f site-scaledown1.yaml                                                  >> /tmp/shutoff-vm.log
kubectl -n viya4 wait --for=delete -l casoperator.sas.com/server=default pods          >> /tmp/shutoff-vm.log
kubectl -n viya4 delete espserver --all                                                >> /tmp/shutoff-vm.log
kubectl apply -f site-scaledown2.yaml                                                  >> /tmp/shutoff-vm.log

echo ""                                                                                >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log
echo "<b>---     2) Stopping Kubernetes and Docker services                   ---</b>" >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log
sudo systemctl stop kubelet
sudo systemctl stop docker

echo ""                                                                                >> /tmp/shutoff-vm.log
sudo systemctl status kubelet                                                          >> /tmp/shutoff-vm.log
echo ""                                                                                >> /tmp/shutoff-vm.log
sudo systemctl status docker                                                           >> /tmp/shutoff-vm.log

echo ""                                                                                >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log
echo "<b>---     3) Shutting down the virtual machine                         ---</b>" >> /tmp/shutoff-vm.log
echo "<b>------------------------------------------------------------------------</b>" >> /tmp/shutoff-vm.log
rm $PIDFILE
sudo shutdown -h now
echo "Goodbye!"                                                                        >> /tmp/shutoff-vm.log

exit 0