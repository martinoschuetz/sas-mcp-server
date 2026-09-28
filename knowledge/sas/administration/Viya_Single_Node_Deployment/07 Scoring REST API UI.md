## Scoring REST API UI



Copy the container image to the local container registry

```shell
echo "10.24.100.18    docker.sas.com" >> /etc/hosts
docker pull docker.sas.com/sdktgo/model-website:1.2.9

# check
docker images | grep model-website
```

Run a local docker container (deploying to Kubernetes did not work, issues with rewriting URLs and sub_filter)

```shell
docker run -p 8081:8080 -d --name model-website \
    --restart=always --add-host=dach-viya4-k8s:192.168.100.199\
    docker.sas.com/sdktgo/model-website:1.2.9
```



