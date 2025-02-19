# 部署 Ceph RBD

依赖 [部署 Ceph 集群](1-deploy-ceph-cluster.md)

## 简介

Ceph RBD 是 Ceph 提供的块存储服务，常用于数据库、虚拟机、容器等场景。

## 在 Ceph 集群上创建 RBD Pool

1. 创建副本 Pool 
    
    ```bash
    # 创建副本 pool 用于 rbd
    ceph osd pool create bj1rbd01 32 32 rep_ssd --bulk
    # 查看 pool 配置
    ceph osd pool get bj1rbd01 all

    # 初始化 pool 用于 rbd
    rbd pool init bj1rbd01
    ```
    
2. 生成 Client 访问 Key
    
    ```bash
    ceph auth get-or-create client.bj1rbd01 mon 'profile rbd' osd 'profile rbd pool=bj1rbd01' mgr 'profile rbd pool=bj1rbd01' |tee /etc/ceph/ceph.client.bj1rbd01.keyring
    chmod 600 /etc/ceph/ceph.client.bj1rbd01.keyring
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
    /etc/ceph/ceph.client.bj1rbd01.keyring
    ```
    
3. 创建 30G image 
    
    ```bash
    # 创建 30G image1
    rbd create --size 30G bj1rbd01/image1

    # 查看
    rbd ls bj1rbd01
    rbd info bj1rbd01/image1
    # 扩容
    rbd resize --size 50G bj1rbd01/image1
    # 缩容
    rbd resize --size 20G bj1rbd01/image1 --allow-shrink
    # 永久删除
    rbd rm bj1rbd01/image1

    # 移动到回收站
    rbd trash mv bj1rbd01/image1
    # 查看回收站
    rbd trash ls bj1rbd01
    # 恢复
    rbd trash restore bj1rbd01/<id>
    # 永久删除
    rbd trash rm bj1rbd01/<id>
    # 清空回收站 (这将永久删除)
    rbd trash purge bj1rbd01
    ```

4. 映射块设备到客户端上

    ```bash
    # 映射到本地
    rbd device map bj1rbd01/image1
    # 查看
    rbd device ls
    # 取消映射
    rbd device unmap bj1rbd01/image1
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
      pool: bj1rbd01
    secret:
      create: true
      userID: bj1rbd01
      userKey: AQCAqvNmLsNMBBAA1hPQOwpe/c0LC3J+ZKaEMw==
    csiConfig:
    - clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
      monitors:
      - 10.128.0.101:6789
      - 10.128.0.102:6789
      - 10.128.0.103:6789
    ```

    > * clusterID & monitors 来自配置 ceph.conf
    > * userID & userKey 来自配置 ceph.client.bj1rbd01.keyring

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


    