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
    # 查看 pool 信息
    ceph osd pool get bj1cfs01_metadata all
    
    # 创建 data pool
    ceph osd pool create bj1cfs01_data 32 32 rep_ssd 
    # (可选) 设置此 pool 预计大小，有助于 PG 数量分配到合理值, 如果后续主要使用 EC POOL 则不需要设置
    ceph osd pool set bj1cfs01_data target_size_bytes 200T
    # 查看 pool 信息
    ceph osd pool get bj1cfs01_data all

    # 查看 PG 自动缩放状态
    ceph osd pool autoscale-status
    ```
    
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
    #ceph fs authorize bj1cfs01 client.bj1cfs01 / rw |sudo tee /etc/ceph/ceph.client.bj1cfs01.keyring
    # 生成的 client key 同时允许 k8s ceph csi 使用
    ceph auth get-or-create client.bj1cfs01 osd 'allow rw tag cephfs *=bj1cfs01' mon 'allow r fsname=bj1cfs01' mds 'allow rw fsname=bj1cfs01' mgr 'allow rw' |sudo tee /etc/ceph/ceph.client.bj1cfs01.keyring
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

# 添加 EC POOL 

```bash
# 创建 ec pool
# (推荐) 设置 bulk 标记，以最大 PG 数量分配，有助于利用更多 OSD 提升性能
ceph osd pool create bj1cfs01_data_ec erasure ec42_ssd --bulk
# (可选) 设置此 pool 预计大小，有助于 PG 数量分配到合理值
ceph osd pool set bj1cfs01_data_ec target_size_bytes 200T
# (必须) 设置此 pool 允许 EC 覆盖写
ceph osd pool set bj1cfs01_data_ec allow_ec_overwrites true

# 添加 ec pool 到 cephfs 中
ceph fs add_data_pool bj1cfs01 bj1cfs01_data_ec

# 设置 layout 需要 p 权限见 quota 配置 (任意挂载节点执行一次)
setfattr -n ceph.dir.layout.pool -v bj1cfs01_data_ec /share
```

## 【可选】修改纠删码配置

注意： 本部分内容只是说明如何修改纠删码池的纠删码配置，默认不用执行。

存储在创建初期可能由于节点个数的问题使用了纠删码配置ec22_ssd，后期随着节点的加入考虑到数据的安全性希望将纠删码配置修改为ec42_ssd。

需要执行如下命令进行调整。

```bash
ceph osd pool set bj1cfs01_data_ec erasure_code_profile ec42_ssd
```

调整纠删码可能会导致该存储池进行数据的重新分配和平衡，执行期间可能会严重影响用户的使用体验。请谨慎执行该操作。


# 使用 K8S PVC

> https://github.com/ceph/ceph-csi

1. 创建 subvolumegroup
    
    ```bash
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
      adminID: bj1cfs01
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
    - adminID, adminKey 来自配置 ceph.client.bj1cfs01.keyring

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

## 自定义 MDS 缓存大小

每个热 inode 大约占 3500 字节，需要根据实际情况调大 mds 缓存大小，否则会造成频繁回收引起元数据响应延迟过大

下面是设置指定文件系统 mds.bj1cfs01 缓存大小为 64GiB

```bash
ceph config set mds.bj1cfs01 mds_cache_memory_limit 68719476736
```

## 多 MDS (可选)

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

# 回收CephFS

当不再使用某文件系统时需要及时回收相关资源，防止出现资源浪费和信息泄露的情况。

回收文件系统资源分为如下几个步骤

**注意：本章节所描述内容全部需要在Ceph的服务端完成。**

如果没有特殊说明，本章节所描述文件系统使用bj1cfs01，挂载目录使用/share。

## 确认是否被客户端使用


通过如下命令确认bj1cfs01文件系统已经没有客户端在使用。

```bash
# ceph fs status
bj1cfs01 - 0 clients
========
RANK  STATE             MDS                ACTIVITY     DNS    INOS   DIRS   CAPS
 0    active  bj1cfs01.mds03.uhppzb  Reqs:    0 /s  23.6k    13     12      0
```

通过上面的ceph fs status命令可以得知该文件系统当前已经没有客户端在使用。该命令可能统计有些延时，也可以通过如下命令实时监控客户端使用情况。

```bash
# ceph tell mds.bj1cfs01.mds03.uhppzb client ls
[]
```

如果得到一个空的数组就表示该文件系统已经没有客户端在使用，可以继续回收操作。

如果文件系统还有被客户端使用，通知管理员进行客户端的卸载。卸载完成后才能进行文件系统的回收工作。

## 清理文件系统上的文件

在进行本章节操作之前请先将被操作的的文件系统挂载到当前服务器的某个目录下。比如将bj1cfs01文件系统挂载到了/share目录下。

本章节的所有操作全部在/share目录下进行。

```bash
# cd /share
进入到/share目录下
# mkdir archive
创建一个archive目录，将用户文件全部移到该目录下。
# mkdir empty; rsync -avP --delete empty/ archive/
一周后执行如下命令进行文件的清理。
如果rsync命令执行后无法清理文件，还可以尝试使用find+rm的组合命令去清理文件。
# find . -exec rm -fr {} \;
如果存在海量的文件和目录结构，建议先清理文件。然后再清理目录。
```

## 清理客户端认证

清理完文件以后需要更换文件系统客户端认证Key，按照如下步骤进行。

```bash
# ceph auth ls
执行上面的命令找到bj1cfs01的客户端认证名称。通常为client.bj1cfs01

# ceph auth rm client.bj1cfs01
删除原来的认证

# 生成的 client key 同时允许 k8s ceph csi 使用
# ceph auth get-or-create client.bj1cfs01 osd 'allow rw tag cephfs *=bj1cfs01' mon 'allow r fsname=bj1cfs01' mds 'allow rw fsname=bj1cfs01' mgr 'allow rw' |sudo tee /etc/ceph/ceph.client.bj1cfs01.keyring
# chmod 600 /etc/ceph/ceph.client.bj1cfs01.keyring
```

原则上MDS和存储池可以复用，为了防止误操作不建议执行删除操作。

# 故障排除

本章节主要描述日常遇到的一些CephFS问题及问题解决方法。

CephFS常见的问题包括响应缓慢、客户端操作卡主等。

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

当发现MDS的CAPS值大于等于 DNS的值可能存在MDS内存不够用的风险后，可以尝试增加MDS服务的内存大小缓解当前遇到的问题。

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


## 性能测试

### elbencho

访问 [elbencho](https://github.com/breuner/elbencho/releases) 下载工具

经过测试，新版本的elbencho貌似有内存泄漏问题。建议使用v3.0.19版本。

#### 大文件读写测试

本章节所示脚本主要进行大文件的如下测试：
1. 4M顺序读写
1. 4K随机读写

```bash
#!/usr/bin/env bash

set -x 

TESTDIR=/share/test
ELBENCHO=/usr/local/bin/elbencho
RESFILE=fs.log
THREADS_LIST="1 4 16 64"
HOSTS_LIST="gn001 gn[001-004] gn[001-016]"
USER=root
IODEPTH=16
TIMELIMIT=20

FIRST_HOST=$(echo $HOSTS_LIST | awk '{print $1}')
LAST_HOST=$(echo $HOSTS_LIST | awk '{print $NF}')
LAST_THREAD=$(echo $THREADS_LIST | awk '{print $NF}')
TOTAL=64

pdsh -w $USER@$LAST_HOST $ELBENCHO --service

for host in $HOSTS_LIST; do
    if [ "$host" == "$FIRST_HOST" ]; then
        thread_list=$THREADS_LIST
    else
        thread_list=$LAST_THREAD
    fi

    for threads in $thread_list; do

          SIZE=$(($TOTAL/$threads))g

          # Sequentially write and read $THREADS large files
          $ELBENCHO --hosts $host -w -n 0 -t $threads -s $SIZE -b 4m --direct --resfile $RESFILE $TESTDIR
          $ELBENCHO --hosts $host -r -n 0 -t $threads -s $SIZE -b 4m --direct --resfile $RESFILE $TESTDIR

          # Random write and read IOPS for max $TIMELIMIT seconds:
          $ELBENCHO --hosts $host -w -n 0 -t $threads -s $SIZE -b 4k --direct --iodepth $IODEPTH --rand --timelimit $TIMELIMIT --resfile $RESFILE $TESTDIR
          $ELBENCHO --hosts $host -r -n 0 -t $threads -s $SIZE -b 4k --direct --iodepth $IODEPTH --rand --timelimit $TIMELIMIT --resfile $RESFILE $TESTDIR
          $ELBENCHO --hosts $host -F -n 0 -t $threads $TESTDIR
    done
done

$ELBENCHO --hosts $USER@$HOSTS --quit
```

#### 多文件测试


```bash
#!/usr/bin/env bash

TESTDIR=/share/test
ELBENCHO=/usr/local/bin/elbencho
RESFILE=fs.log
DIRS=1
FILES=128
THREADS_LIST="1 4 16 64"
SIZE_LIST="4k 128k 4m 4g"
HOSTS_LIST="gn001 gn[001-004] gn[001-016]"
USER=root

FIRST_HOST=$(echo $HOSTS_LIST | awk '{print $1}')
LAST_HOST=$(echo $HOSTS_LIST | awk '{print $NF}')
LAST_THREAD=$(echo $THREADS_LIST | awk '{print $NF}')
LAST_SIZE=$(echo $SIZE_LIST | awk '{print $NF}')

pdsh -w $USER@$LAST_HOST $ELBENCHO --service

for host in $HOSTS_LIST; do
    if [ "$host" == "$FIRST_HOST" ]; then
        thread_list=$THREADS_LIST
    else
        thread_list=$LAST_THREAD
    fi

    for threads in $thread_list; do
        for size in $SIZE_LIST; do
            #如果是以g结尾就设定4m块大小
            if [[ $(rev <<< "$size" | head -c 1) == "g" ]]; then
                files=1
                block_size="4m"
            else
                files=$FILES
                block_size=$size
            fi

            # Write
            $ELBENCHO --hosts $host  \
                    -w -d --direct -t $threads -n $DIRS -N $files -s $size -b $block_size --resfile $RESFILE $TESTDIR
            # Read
            $ELBENCHO --hosts $host  \
                    -r --direct -t $threads -n $DIRS -N $files -s $size -b $block_size --resfile $RESFILE $TESTDIR
            # Delete
            $ELBENCHO --hosts $host  \
                    -D -F -t $threads -n $DIRS -N $files $TESTDIR
        done
    done
done

$ELBENCHO --hosts $USER@$HOSTS --quit
```

## 监控

如果没有 `ceph_mds_xxx` metrics 需要执行 `ceph config set mgr mgr/prometheus/exclude_perf_counters false` 切回从 mgr 获取 metrics
