# 部署 Ceph RBD

依赖 [部署 Ceph 集群](1-deploy-ceph-cluster.md)

## 简介

Ceph RBD 是 Ceph 提供的块存储服务，常用于数据库、虚拟机、容器等场景。

## 在 Ceph 集群上创建 RBD Pool

1. 创建副本 Pool 
    
    ```bash
    # 创建副本 pool 用于 rbd
    ceph osd pool create rbd1 128 128 rep_ssd
    # 设置副本数，hdd 使用 3 副本，ssd 使用 2 副本
    ceph osd pool set rbd1 size 2
    # 设置目标大小比例
    ceph osd pool set rbd1 target_size_ratio 0.3
    # 查看 pool 配置
    ceph osd pool get rbd1 all

    # 初始化 pool 用于 rbd
    rbd pool init rbd1
    ```
    
2. 生成 Client 访问 Key
    
    ```bash
    ceph auth get-or-create client.rbd1 mon 'profile rbd' osd 'profile rbd pool=rbd1' mgr 'profile rbd pool=rbd1' |tee /etc/ceph/ceph.client.rbd1.keyring
    chmod 600 /etc/ceph/ceph.client.rbd1.keyring
    ```

## 在 Linux 客户端使用

1. 安装 rbd 工具

    ```bash
    apt install -y ceph-common
    rbd --version
    ```
    
2. 获取 conf 和 key 文件存放到 `/etc/ceph` 目录下
    
    ```bash
    /etc/ceph/ceph.conf
    /etc/ceph/ceph.client.rbd1.keyring
    ```
    
3. 创建 30G image 
    
    ```bash
    # 创建 30G image1
    rbd create --size 30G rbd1/image1

    # 查看
    rbd ls rbd1
    rbd info rbd1/image1
    # 扩容
    rbd resize --size 50G rbd1/image1
    # 缩容
    rbd resize --size 20G rbd1/image1 --allow-shrink
    # 永久删除
    rbd rm rbd1/image1

    # 移动到回收站
    rbd trash mv rbd1/image1
    # 查看回收站
    rbd trash ls rbd1
    # 恢复
    rbd trash restore rbd1/<id>
    # 永久删除
    rbd trash rm rbd1/<id>
    # 清空回收站 (这将永久删除)
    rbd trash purge rbd1
    ```

4. 映射块设备到客户端上

    ```bash
    # 映射到本地
    rbd device map rbd1/image1
    # 查看
    rbd device ls
    # 取消映射
    rbd device unmap rbd1/image1
    ```

5. 格式化为本地文件系统并挂载使用

    ```bash
    mkfs.xfs /dev/rbd0
    mkdir /mnt/image1
    mount /dev/rbd0 /mnt/image1
    ```

## 在 Kubernetes 上使用

1. 准备自定义 helm values

    ```yaml
    # values.yaml
    storageClass:
      create: true
      name: csi-rbd-sc
      clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
      pool: rbd1
    secret:
      create: true
      userID: rbd1
      userKey: AQCAqvNmLsNMBBAA1hPQOwpe/c0LC3J+ZKaEMw==
    csiConfig:
    - clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
      monitors:
      - 172.19.12.1:6789
      - 172.19.12.2:6789
      - 172.19.12.3:6789
    ```

    > * clusterID & monitors 来自配置 ceph.conf
    > * userID & userKey 来自配置 ceph.client.rbd1.keyring

2. 安装 ceph-csi-rbd

    ```bash
    helm repo add ceph-csi https://ceph.github.io/csi-charts
    helm upgrade -i -f values.yaml --namespace ceph-csi-rbd --create-namespace ceph-csi-rbd ceph-csi/ceph-csi-rbd
    ```

3. 运行 ceph pvc 示例

    ```yaml
    # tests.yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: csi-rbd-pvc
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 30Gi
      storageClassName: csi-rbd-sc
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      name: csi-rbd-pod
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        volumeMounts:
        - name: mypvc
          mountPath: /var/lib/www
      volumes:
      - name: mypvc
        persistentVolumeClaim:
          claimName: csi-rbd-pvc
    ```

    提交

    ```bash
    kubectl apply -f tests.yaml
    ```


    