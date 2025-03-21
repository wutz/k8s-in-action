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
    
    ceph osd pool create cephfs1_data 128 128 rep_ssd --bulk
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
setfattr -n ceph.dir.layout.pool -v cephfs1_data_ec /share
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
      name: csi-cephfs-sc
      clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
      fsName: cephfs1
    secret:
      create: true
      adminID: cephfs1k
      adminKey: <---key--->
    csiConfig:
      - clusterID: c966095a-6e4e-11ef-82d6-0131360f7c6f
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


# 故障排除

本章节主要描述日常遇到的一些CephFS问题如何进行解决。CephFS常见的问题包括响应缓慢、卡主。

## CephFS响应缓慢

本章节主要描述由于CephFS组件（MDS）造成的响应缓慢问题，请先确认你的单盘和OSD Pool性能没有问题。

### 获取CephFS MDS概要信息

执行如下命令获取到指定CephFS的概要信息
```bash
root@mn01:~# ceph fs status bjcfs01
bjcfs01 - 96 clients
========
RANK  STATE             MDS                ACTIVITY     DNS    INOS   DIRS   CAPS
 0    active  bjcfs01.mn01.zxhhrq  Reqs:  2895 /s      30.6M  30.5M  1997k  21.5M
       POOL          TYPE     USED  AVAIL
bjcfs01_metadata  metadata   105G    114T
bjcfs01_data      data       80.6T   114T
```

96 clients表示已建立链接的客户端的数量。

bjcfs01.mn01.zxhhrq 表示CephFS bjcfs01的主MDS运行在mn01节点上。

DNS (Directory Number of Entries) 30.6M 表示文件系统中共计有 3050万个目录条目 (目录以及文件)，这个数字反映了 CephFS 中文件和目录的总数。

INOS 30.5M 表示inode的总数。

DIRS 1997k 表示文件系统中有 1997000 个目录。

**CAPS** 21.5M 表示已经授予给客户端的 capabilities 的数量。 高 CAPS 也意味着客户端对 CephFS 的活跃使用，**如果CAPS的值大于等于 DNS的值可能存在MDS内存不够用的风险**。


### 获取CephFS MDS的主从信息

通过如下命令获取CephFS MDS主从服务的信息。

```bash
root@mn01:~# ceph orch ps --service_name mds.bjcfs01
NAME                          HOST      PORTS  STATUS             REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
mds.bjcfs01.mn01.vogufr        mn01             running (4w)     5m ago     4w    23.8M        -  19.2.1   f2efb0401a30  265fe7d39a75
mds.bjcfs01.mn02.zxhhrq        mn02             running (4w)     4m ago     4w     115G        -  19.2.1   f2efb0401a30  4f1b3a7617a6
mds.bjcfs01.mn03.vgjudl        mn03             running (4w)     4m ago     4w    25.6M        -  19.2.1   f2efb0401a30  462ac6e84fdf
```

通过如上信息大致的得到bjcfs01文件系统所有MDS服务的信息。重点关注 MEM USE 的大小，该值表示此MDS服务占用的内存大小。

另外一个获取MDS服务的方法是直接登录到MDS服务对应的节点使用top观察其内存占用。

### 获取CephFS客户端访问请求事件

通过如下命令可以获取CephFS客户端的请求事件。

```bash
root@mn01:~# ceph tell mds.bjcfs01.mn01.zxhhrq dump_ops_in_flight
```

默认该命令会输出所有客户端操作内容，通常需要过滤出需要用到的操作和客户端信息

过滤出readdir操作

```bash
root@mn01:~# ceph tell mds.bjcfs01.mn01.zxhhrq dump_ops_in_flight |grep readdir
以下为部分输出信息
"description": "client_request(client.165916:7196203 setfilelock rule 1, type 2, owner 16963308566499810484, pid 1461127, start 0, length 0, wait 1 #0x100120f7b34 2025-03-21T08:13:26.842573+0000 caller_uid=17448, caller_gid=17562{17562,})",
```

上面的输出信息中包含client.165916就是客户端的IP。

排查客户端具体信息

```bash
root@mn01:~# ceph tell mds.bjcfs01.mn01.zxhhrq client ls |grep client.165916
    {
        "id": 205000,
        "entity": {
            "name": {
                "type": "client",
                "num": 205000
            },
            "addr": {
                "type": "v1",
                "addr": "10.251.10.17:0",
                "nonce": 1156683885
            }
        }
      ...
    }
```

这里可以通过client.165916获取到客户端的id是205000，IP地址10.251.10.105。

获取到客户端的IP地址后可以去对应节点观察客户端做了什么操作。

### 响应慢处理方案

####  增加MDS主服务内存容量

当发现MDS的CAPS值大于等于 DNS的值可能存在MDS内存不够用的风险后可以尝试增加MDS服务的内存大小缓解当前遇到的问题.

```bash
# ceph config set mds.bj1cfs01 mds_cache_memory_limit 68719476736
```

修改后时刻观察MDS服务的内存占用情况和响应情况。

#### 驱逐客户端

当文件系统客户端无响应或出现其他异常行为时，可能需要强制终止其对文件系统的访问。这个过程称为驱逐。

客户端可以自动驱逐（如果它们未能及时与 MDS 通信），或者手动驱逐（由系统管理员）。

客户端驱逐过程适用于所有类型的客户端，包括 FUSE 挂载、内核挂载、nfs-ganesha 网关以及任何使用 libcephfs 的进程。

在三种情况下，客户端可能会被自动驱逐:

1. 在一个活动的 MDS 守护进程上，如果一个客户端超过 session_autoclose 秒（一个文件系统变量，默认为 300 秒）没有与 MDS 通信，那么它将被自动驱逐。
1. 在一个活动的 MDS 守护进程上，如果一个客户端超过 mds_cap_revoke_eviction_timeout 秒（配置选项）没有响应 cap 撤销消息。 默认情况下，此功能处于禁用状态。
1. 在 MDS 启动期间（包括故障转移时），MDS 会经历一个名为 reconnect 的状态。在此状态下，它会等待所有客户端连接到新的 MDS 守护程序。如果任何客户端未能在时间窗口（ mds_reconnect_timeout ，默认为 45 秒）内执行此操作，则它们将被驱逐

通过如下命令获取到客户端id
```bash
ceph tell mds.bjcfs01.mn01.zxhhrq client ls

[
    {
        "id": 205000,
        "entity": {
            "name": {
                "type": "client",
                "num": 205000
            },
            "addr": {
                "type": "v1",
                "addr": "10.251.10.17:0",
                "nonce": 1156683885
            }
        }
      ...
    }
]
```

使用如下命令驱逐客户端

```bash
# ceph tell mds.bjcfs01.mn01.zxhhrq client evict id=205000
# ceph tell mds.bjcfs01.mn01.zxhhrq client evict client_metadata.=205000
```

参考文档:  https://docs.ceph.com/en/latest/cephfs/eviction/



