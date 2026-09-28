# singlenode

Deployment notes for a single-node Viya4 deployment on AWS (Viya-to-go)



## Add annotation when preparing a new AMI

```
kubectl annotate nodes dach-viya4-k8s viya-to-go/ami-version=v15 --overwrite
kubectl annotate nodes dach-viya4-k8s viya-to-go/sas-version=2020.1.1 --overwrite
```



## TODOs

* add ESP (new order)
* add R Studio + SWAT
* add more SAS/Python packages (dlpy ...)
