# 创建并使用Redis集群

本文档描述如何通过kbcli命令在Kubernetes集群内创建一套Redis集群。

# 创建步骤

## 创建命名空间

执行如下命令创建Redis集群专用命名空间。

```bash
$ kubectl create ns redis
```

以下命令全部在redis命名空间中进行，请先切换到该空间。

## 确认可安装的Redis版本

执行如下步骤确认可安装的Redis版本

```bash
$ kbcli clusterversion list|grep redis
redis-7.0.6          redis                Available   false        Oct 21,2024 18:07 UTC+0800
redis-7.2.4          redis                Available   false        Oct 21,2024 18:07 UTC+0800
```

这里以NAME为redis开头的版本为例，可以看到默认0.9.1版本的KubeBlocks目前提供了7.0.6和7.2.4两个Redis版本。

## 创建单机版集群

单机版集群就是启动一个Redis实例，该实例不具备主备切换的功能。

即将被创建的Redis集群名称为mycluster

```bash
$ kbcli cluster create redis --mode standalone mycluster --cpu 1 --memory 1
```

以上命令创建一个单节点的Redis集群，Redis版本为8.0.33。

硬件配置为CPU为1核，内存1GB

## 创建主备集群

主备复制集群会启动一主一从实例，当主出现故障的时候自动切换。

该集群通过redis-sentinel负责进行主备健康度的侦测和切换。

即将被创建的Redis集群名称为mycluster

```bash
$ kbcli cluster create mycluster --cluster-definition redis --cluster-version redis-7.2.4 --pvc type=redis,name=data,mode=ReadWriteOnce,size=20Gi --set cpu=1,memory=1Gi,replicas=2

```

以上命令创建一套具有一主一从两个节点的Redis集群，Redis版本为7.2.4。

硬件配置为CPU为1核，内存1GB，数据盘20GB（/data）

## 查询集群状态

```bash
$ kbcli cluster describe mycluster
Name: mycluster	 Created Time: Oct 24,2024 11:29 UTC+0800
NAMESPACE   CLUSTER-DEFINITION   VERSION   STATUS     TERMINATION-POLICY
redis       redis                          Creating   Delete

Endpoints:
COMPONENT   MODE        INTERNAL                                             EXTERNAL
redis       ReadWrite   mycluster-redis-redis.redis.svc.cluster.local:6379   <none>

Topology:
COMPONENT   INSTANCE            ROLE     STATUS    AZ       NODE                           CREATED-TIME
redis       mycluster-redis-0   <none>   Running   <none>   ceph04.dev1.lab/172.18.3.194   Oct 24,2024 11:29 UTC+0800

Resources Allocation:
COMPONENT   DEDICATED   CPU(REQUEST/LIMIT)   MEMORY(REQUEST/LIMIT)   STORAGE-SIZE   STORAGE-CLASS
redis       false       1 / 1                1Gi / 1Gi               data:20Gi      local-path

Images:
COMPONENT   TYPE   IMAGE
redis              apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com/apecloud/redis-stack-server:7.2.0-v10

Data Protection:
BACKUP-REPO   AUTO-BACKUP   BACKUP-SCHEDULE   BACKUP-METHOD   BACKUP-RETENTION   RECOVERABLE-TIME

Show cluster events: kbcli cluster list-events -n redis mycluster
```

# 连接到Redis集群


## 开放Redis连接

开放单机版Redis连接

```bash
$ kubectl expose svc mycluster-redis-redis --name mycluster-redis-redis-lb --type LoadBalancer --port 6379 --target-port 6379
```

开发主备集群Redis连接

```bash
kubectl expose svc mycluster-redis--name mycluster-redis-lb --type LoadBalancer --port 6379 --target-port 6379
```

## 连接到Redis并创建用户

```bash
$ kbcli cluster connect mycluster
Connect to instance mycluster-redis-0
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> acl setuser default on >I7kQpZUgmzxqw +@all -@dangerous ~*
OK
127.0.0.1:6379>
```


# 维护集群

## 实例扩容

实例扩容分为水平扩容和垂直扩容，不管哪种扩容目的就是提高整套集群的数据处理能力。

垂直扩容就是变更Redis集群中每个角色的CPU核数和内存容量大小。

水平扩容就是增加相同配置的从节点以增加集群的副本数量和只读能力。

### 垂直扩容

垂直扩容就是在不增加实例的前提下对每个现有实例进行CPU和内存大小的变更。

加入要把现有Redis集群实例配置更改为2核4GB配置，则进行如下操作

```bash
$ kbcli cluster vscale mycluster --components=redis --cpu=2 --memory=4G 
```

### 水平扩容

就是水平扩展相同配置的从节点。主从集群主节点只能有一个，可以扩容从节点的个数。

如果需要把当前集群设置为一主2从3副本的组织形式，就可以执行如下命令

```bash
$ kbcli cluster hscale mycluster --components="redis" --replicas=3
```

## 切换主从角色

执行如下命令进行切换

```bash
$ kbcli cluster promote mycluster --instance='mycluster-redis-1'
```

如果集群只有2副本一主一从的形式就不用执行--instance参数.