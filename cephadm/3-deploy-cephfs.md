# 部署 CephFS

依赖 [部署 Ceph 集群](1-deploy-ceph-cluster.md)

## 简介

CephFS 是一个构建在 Ceph RADOS 之上并且兼容 POSIX 标准的文件系统. 

CephFS 提供一些功能:

- 可扩展性
- 共享文件系统
- 多文件系统: 每个文件系统使用自己独立的 Pool 和 MDS
- 高可用性
- 可配置文件和目录的布局: 允许使用不同的 Pool 和文件条带模式
- POSIX ACL
- Quota: 支持到目录级别配额

## 组件

- Client: 用户空间的 `ceph-fuse` 或者内核空间的 `kcepfs`
- MDS: 元数据服务

## MDS

- Status: Active 或者 Standy (缺省只使用一个 Active MDS)
- Fail: 当 Active MDS 不响应时, Mon 会等待 `mds_beacon_grace` 时间后, 如果还不响应则标记 MDS 为 `laggy` . 然后 Standy MDS 变成 Active 状态
- Rank: 定义最大 Active MDS 数量用于分担元数据负载, `max_mds` 配置 rank 数量
- Cache:
    - `mds_cache_memory_limit` 设置 MDS 使用内存大小 `ceph config set global mds_cache_memory_limit 34359738368`
    - `mds_cache_size` 设置 MDS 使用 `inode` 数量
- Affinity: 配置偏好使用的 MDS, 通过设置 `mds_join_fs` 在 Standby MDS 上

## 部署

1. 调整 mds 缺省使用内存大小
  
    ```bash
    ceph config set global mds_cache_memory_limit 34359738368
    ```

2. 创建 2 个副本 Pool 分别用于 metadata 和 data
    
    ```bash
    # 创建 metadata pool
    ceph osd pool create bj1cfs01_metadata 32 32 rep_ssd
    ceph osd pool application enable bj1cfs01_metadata cephfs
    # 设置副本数量
    ceph osd pool set bj1cfs01_metadata size 2
    # 查看 pool 信息
    ceph osd pool get bj1cfs01_metadata all
    
    # 创建 data pool, 使用 bulk 模式使用更多 PG 以提升性能
    ceph osd pool create bj1cfs01_data 128 128 rep_ssd --bulk
    ceph osd pool application enable bj1cfs01_data cephfs
    # 设置副本数量
    ceph osd pool set bj1cfs01_data size 2
    # 查看 pool 信息
    ceph osd pool get bj1cfs01_data all

    # 查看 PG 自动缩放状态
    ceph osd pool autoscale-status
    ```

    > * 使用 HDD 必须使用缺省 3 副本
    > * 使用 SSD 可以使用 2 或者 3 副本
    
3. 创建 CephFS
    
    ```bash
    # 创建 CephFS，名字为 bj1cfs01
    ceph fs new bj1cfs01 bj1cfs01_metadata bj1cfs01_data
    
    # 查看 CephFS
    ceph fs ls
    ceph fs get bj1cfs01
    ```
    
4. 部署 MDS 到节点上
    
    ```bash
    # 部署 MDS 到 2 个节点
    ceph orch apply mds bj1cfs01 --placement="2 label:mds"
    
    # 查看 MDS 状态
    ceph mds stat
    ```
    
5. 生成 Client 访问 Key
    
    ```bash
    ceph fs authorize bj1cfs01 client.bj1cfs01 / rw |sudo tee /etc/ceph/ceph.client.bj1cfs01.keyring
    chmod 600 /etc/ceph/ceph.client.bj1cfs01.keyring
    ```
    
6. 发送配置和 Key 到 Client
    
    ```bash
    ssh client "mkdir /etc/ceph"
    scp /etc/ceph/ceph.conf client:/etc/ceph
    scp ceph.client.bj1cfs01.keyring client:/etc/ceph
    ```
    
7. 挂载
    
    ```bash
    # Ubuntu 20.04 及以上
    apt install ceph-common 
    
    # CentOS 7
    cat > /etc/yum.repos.d/ceph.repo << 'EOF'
    [ceph]
    name=Ceph packages for $basearch
    baseurl=https://mirrors.tuna.tsinghua.edu.cn/ceph/rpm-15.2.17/el7/$basearch
    enabled=1
    priority=2
    gpgcheck=1
    gpgkey=https://download.ceph.com/keys/release.asc
    EOF
    yum install ceph-common
    
    mkdir /share
    mount -t ceph :/ /share -o name=bj1cfs01,fs=bj1cfs01
    ```
    
8. 设置开机挂载
    
    ```bash
    vim /etc/fstab
    # auto mount cephfs
    :/ /share ceph name=bj1cfs01,fs=bj1cfs01 0 0
    ```

# 设置 quota

> 参考：
> - https://docs.ceph.com/en/latest/cephfs/quota/
> - https://docs.ceph.com/en/latest/cephfs/client-auth/

如果需要设置 quota 则需要额外 p 权限。设置 quota 还会改变 df 大小与 quota 一致。

```bash
ceph fs authorize bj1cfs01 client.bj1cfs01p / rwp |tee /etc/ceph/ceph.client.bj1cfs01p.keyring
chmod 600 /etc/ceph/ceph.client.bj1cfs01p.keyring
scp ceph.client.bj1cfs01p.keyring client:/etc/ceph
mount -t ceph :/ /share -o name=bj1cfs01p,fs=bj1cfs01

# 设置 10TiB 配额
setfattr -n ceph.quota.max_bytes -v 10995116277760 /share
getfattr -n ceph.quota.max_bytes /share
# 使用量
getfattr -d -m ceph.dir.* /share 
# 新 kernel 使用
getfattr -n ceph.dir.rbytes /share
```

# 添加 EC POOL (可选)

> 可选，根据需求决定是否使用

```bash
# 创建 ec pool
ceph osd pool create bj1cfs01_data_ec erasure ec42_ssd
ceph osd pool set bj1cfs01_data_ec allow_ec_overwrites true

# 添加 ec pool 到 cephfs 中
ceph fs add_data_pool bj1cfs01 bj1cfs01_data_ec

# 设置 layout 需要 p 权限见 quota 配置
setfattr -n ceph.dir.layout.pool -v bj1cfs01_data_ec /share
```

# 使用 K8S PVC

> https://github.com/ceph/ceph-csi

1. 在 ceph cluster 中准备 key
    
    ```bash
    ceph auth get-or-create client.bj1cfs01k osd 'allow rw tag cephfs *=bj1cfs01' mon 'allow r fsname=bj1cfs01' mds 'allow rw fsname=bj1cfs01' mgr 'allow rw' |sudo tee /etc/ceph/ceph.client.bj1cfs01k.keyring
    ceph fs subvolumegroup create bj1cfs01 csi
    ```
    
2. 准备 helm values.yaml
    
    ```yaml
    storageClass:
      create: true
      name: csi-cephfs-sc
      clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
      fsName: bj1cfs01
    secret:
      create: true
      adminID: bj1cfs01k
      adminKey: <---key--->
    csiConfig:
      - clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
        monitors:
          - 10.128.0.101:6789
          - 10.128.0.102:6789
          - 10.128.0.103:6789
          - 10.128.0.104:6789
          - 10.128.0.105:6789
    ```
    
    - clusterID, monitors 来自配置 ceph.conf
    - adminID, adminKey 来自配置 ceph.client.bj1cfs01k.keyring

3. 安装 ceph-csi
    
    ```bash
    $ helm repo add ceph-csi https://ceph.github.io/csi-charts
    $ kubectl create namespace ceph-csi-cephfs
    $ helm install --namespace "ceph-csi-cephfs" -f values.yaml "ceph-csi-cephfs" ceph-csi/ceph-csi-cephfs
    $ helm status "ceph-csi-cephfs"
    
    # 比如在需要自定义 image, 可以使用 raw yaml 安装，这时执行 helm template 导出
    $ helm template -f myvalues.yaml  ceph-csi/ceph-csi-cephfs > ceph-csi.yaml
    $ kubectl apply -f ceph-csi.yaml
    ```
    
4. 运行 ceph pvc 示例
    
    ```yaml
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: csi-cephfs-pvc
    spec:
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 1Gi
      storageClassName: csi-cephfs-sc
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      name: csi-cephfs-demo-pod
    spec:
      containers:
        - name: web-server
          image: docker.io/library/nginx:latest
          volumeMounts:
            - name: mypvc
              mountPath: /var/lib/www
      volumes:
        - name: mypvc
          persistentVolumeClaim:
            claimName: csi-cephfs-pvc
            readOnly: false
    ```
    
    ```bash
    kubectl apply -f pod-pvc.yaml
    ```

# 多 MDS (可选)

- 使用多个 mds 服务 一个 cephfs 可以分担请求压力，以及分散元数据缓存到不同的 mds 上
- 为 HA，max_mds 数量必须小于 mds service 数量（即执行 `ceph orch apply mds cephfs1 --placement=3`  数量）

```bash
# 关闭 mds balance （https://github.com/ceph/ceph/pull/52196/files）
ceph config set mds mds_bal_interval 0

# 静态均衡 /share/home 的子目录
setfattr -n ceph.dir.pin.distributed -v 1 /share/home

# 增加 mds 数量到 2
ceph fs set bj1cfs01 max_mds 2
# 缩减 mds 数量到 1
ceph fs set bj1cfs01 max_mds 1

# 查询
ceph fs get bj1cfs01
ceph mds stat
ceph fs status
```