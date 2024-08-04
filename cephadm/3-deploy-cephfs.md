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
    - `mds_cache_memory_limit` 设置 MDS 使用内存大小 `ceph config set global mds_cache_memory_limit 68719476736`
    - `mds_cache_size` 设置 MDS 使用 `inode` 数量
- Affinity: 配置偏好使用的 MDS, 通过设置 `mds_join_fs` 在 Standby MDS 上

## 部署

1. 为用于部署 mds 服务节点打上 label
    
    ```bash
    ceph orch host label add sn001.hs1.local mds
    ceph orch host label add sn002.hs1.local mds
    ceph orch host label add sn003.hs1.local mds
    ```
    
2. 创建 2 个副本 Pool 分别用于 metadata 和 data
    
    ```bash
    ceph osd pool create cephfs1_metadata 128 128 rep_ssd
    ceph osd pool set cephfs1_metadata size 2
    ceph osd pool get cephfs1_metadata all
    
    ceph osd pool create cephfs1_data 128 128 rep_ssd
    ceph osd pool set cephfs1_data size 2
    ceph osd pool set cephfs1_data target_size_ratio 0.3
    ceph osd pool set cephfs1_data bulk true
    ceph osd pool get cephfs1_data all
    
    ceph osd pool autoscale-status
    ```
    
3. 创建 CephFS
    
    ```bash
    ceph fs new cephfs1 cephfs1_metadata cephfs1_data
    
    ceph fs ls
    ceph fs get cephfs1
    ```
    
    > `cephfs1` 为自定义的名称
4. 部署 MDS 到节点上
    
    ```bash
    ceph orch apply mds cephfs1 --placement=3
    # or
    ceph orch apply mds cephfs1 --placement="3 label:mds"
    
    ceph mds stat
    ```
    
5. 生成 Client 访问 Key
    
    ```bash
    ceph fs authorize cephfs1 client.cephfs1 / rw |sudo tee /etc/ceph/ceph.client.cephfs1.keyring
    chmod 600 /etc/ceph/ceph.client.cephfs1.keyring
    ```
    
6. 发送配置和 Key 到 Client
    
    ```bash
    ssh client "mkdir /etc/ceph"
    scp /etc/ceph/ceph.conf client:/etc/ceph
    scp ceph.client.cephfs1.keyring client:/etc/ceph
    ```
    
7. 挂载
    
    ```bash
    # Ubuntu 20.04
    apt install epel-release ceph-common 
    
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
    mount -t ceph :/ /share -o name=cephfs1,fs=cephfs1
    
    ```
    
8. 设置开机挂载
    
    ```bash
    vim /etc/fstab
    # auto mount cephfs
    :/ /cephfs1 ceph name=cephfs1,fs=cephfs1 0 0
    ```

# 设置 quota

> 参考：
> - https://docs.ceph.com/en/latest/cephfs/quota/
> - https://docs.ceph.com/en/latest/cephfs/client-auth/

如果需要设置 quota 则需要额外 p 权限。设置 quota 还会改变 df 大小与 quota 一致。

```bash
ceph fs authorize cephfs1 client.cephfs1p / rwp |tee /etc/ceph/ceph.client.cephfs1p.keyring
chmod 600 /etc/ceph/ceph.client.cephfs1p.keyring
scp ceph.client.cephfs1p.keyring client:/etc/ceph
mount -t ceph :/ /share -o name=cephfs1p,fs=cephfs1

# 设置 10TiB 配额
setfattr -n ceph.quota.max_bytes -v 10995116277760 /share
getfattr -n ceph.quota.max_bytes /share
# 使用量
getfattr -d -m ceph.dir.* /share 
# 新 kernel 使用
getfattr -n ceph.dir.rbytes /share
```

# 添加 EC POOL

> 可选，根据需求决定是否使用

```bash
# 创建 ec pool
ceph osd erasure-code-profile set ec_ssd k=4 m=2 crush-root=default crush-failure-domain=host crush-device-class=ssd
ceph osd pool create cephfs1_data_ec erasure ec_ssd
ceph osd pool set cephfs1_data_ec allow_ec_overwrites true

# 添加 ec pool 到 cephfs 中
ceph fs add_data_pool cephfs1 cephfs1_data_ec

# 设置 layout 需要 p 权限见 quota 配置
mkdir /share/ecdir
setfattr -n ceph.dir.layout.pool -v cephfs1_data_ec /share/ecdir
```

# 使用 K8S PVC

> https://github.com/ceph/ceph-csi

1. 在 ceph cluster 中准备 key
    
    ```bash
    ceph auth get-or-create client.cephfs1k osd 'allow rw tag cephfs *=cephfs1' mon 'allow r fsname=cephfs1' mds 'allow rw fsname=cephfs1' mgr 'allow rw' |sudo tee /etc/ceph/ceph.client.cephfs1k.keyring
    ceph fs subvolumegroup create cephfs1 csi
    ```
    
2. 准备 helm values.yaml
    
    ```yaml
    storageClass:
      create: true
      clusterID: f89b88ea-4dad-11ec-a673-4d72a9026ccc
      fsName: cephfs1
      reclaimPolicy: Retain
    secret:
      create: true
      adminID: cephfs1k
      adminKey: <---key--->
    csiConfig:
      - clusterID: f89b88ea-4dad-11ec-a673-4d72a9026ccc
        monitors:
          - 172.19.12.1:6789
          - 172.19.12.2:6789
          - 172.19.12.3:6789
    ```
    
    - clusterID, monitors 来自配置 ceph.conf
    - adminID, adminKey 来自配置 ceph.client.cephfs1k.keyring

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

# 多 MDS

- 使用多个 mds 服务 一个 cephfs 可以分担请求压力，以及分散元数据缓存到不同的 mds 上
- 为 HA，max_mds 数量必须小于 mds service 数量（即执行 `ceph orch apply mds cephfs1 --placement=3`  数量）

```bash
# 关闭 mds balance （https://github.com/ceph/ceph/pull/52196/files）
ceph config set mds mds_bal_interval 0

# 静态均衡 /cephfs1/home 的子目录
setfattr -n ceph.dir.pin.distributed -v 1 /cephfs1/home

# 增加 mds 数量到 2
ceph fs set <fs_name> max_mds 2
# 缩减 mds 数量到 1
ceph fs set <fs_name> max_mds 1

# 查询
ceph fs get cephfs1
ceph mds stat
ceph fs status
```