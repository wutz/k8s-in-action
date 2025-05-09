# ceph-csi-cephfs

用于添加 cephfs csi 进入集群

## 部署

1. 部署 csi

    修改 [values.yml](values.yml) 中的 Ceph 集群连接信息，信息来自 `ceph.conf` 文件

    如果添加多个 Ceph 集群，在 `values.yml` 中继续添加连接信息即可

    ```bash
    helmwave up --build
    ```

2. 部署 storageclass

    假如命名 storageclass 为 `shared-nvme`，则需要创建 `shared-nvme` 目录，并创建 `secret.yaml` 和 `storageclass.yaml` 文件

    其中 `secret.yaml` 文件中的 `adminID` 来自 `ceph.client.bj1cfs01.keyring` 名称 `bj1cfs01`, `adminKey` 来自 `ceph.client.bj1cfs01.keyring` 文件内容
    其中 `storageclass.yaml` 文件中的 `fsName` 来自 `ceph.client.bj1cfs01.keyring` 名中的 `bj1cfs01`

    ```bash
    kubectl apply -k shared-nvme/
    ```

## 测试

修改 [tests.yaml](tests.yaml) 中的 `storageClassName` 为 `shared-nvme`，然后运行

```bash
kubectl apply -f tests.yaml
```

进来 pod 中观测挂载的目录

```bash
kubectl exec -it csi-cephfs-demo-pod -- /bin/bash
df -h /var/lib/www
```

测试完毕后，删除 pod 和 pvc

```bash
kubectl delete -f tests.yaml
```




