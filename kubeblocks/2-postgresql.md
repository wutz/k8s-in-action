# 创建并使用PostgreSQL集群

本文档描述如何通过kbcli命令在Kubernetes集群内创建一套PostgreSQL集群。

# 创建步骤

## 创建命名空间

执行如下命令创建PostgreSQL集群专用命名空间。

```bash
$ kubectl create ns pg
```

以下命令全部在postgresql命名空间中进行，请先切换到该空间。

## 确认可安装的PostgreSQL版本

执行如下步骤确认可安装的PostgreSQL版本

```bash
$ kbcli clusterversion list |grep postgresql
NAME                 CLUSTER-DEFINITION   STATUS      IS-DEFAULT   CREATED-TIME
postgresql-12.14.0   postgresql           Available   false        Oct 21,2024 18:07 UTC+0800
postgresql-12.14.1   postgresql           Available   false        Oct 21,2024 18:07 UTC+0800
postgresql-12.15.0   postgresql           Available   false        Oct 21,2024 18:07 UTC+0800
postgresql-14.7.2    postgresql           Available   false        Oct 21,2024 18:07 UTC+0800
postgresql-14.8.0    postgresql           Available   true         Oct 21,2024 18:07 UTC+0800
postgresql-15.7.0    postgresql           Available   false        Oct 21,2024 18:07 UTC+0800
postgresql-16.4.0    postgresql           Available   false        Oct 21,2024 18:07 UTC+0800
```

这里以NAME为postgresql开头的版本为例，可以看到默认0.9.1版本的KubeBlocks目前提供了12、14、15、16四个PostgreSQL版本。

## 创建单机版集群

单机版集群就是启动一个PostgreSQL实例，该实例不具备主备切换的功能。

即将被创建的PostgreSQL集群名称为mycluster

```bash
$ kbcli cluster create mycluster --cluster-definition postgresql --cluster-version postgresql-14.8.0 --pvc type=postgresql,name=data,mode=ReadWriteOnce,size=20Gi --set cpu=1,memory=1Gi,replicas=1
```

以上命令创建一个单节点的PostgreSQL集群，PostgreSQL版本为postgresql-14.8.0。

硬件配置为CPU为1核，内存1GB，数据盘20GB（/home/postgres/pgdata）

## 创建主备集群

主备复制集群会启动一主一从实例，当主出现故障的时候自动切换。

即将被创建的PostgreSQL集群名称为mycluster

```bash
$ kbcli cluster create mycluster --cluster-definition postgresql --cluster-version postgresql-8.0.33 --pvc type=postgresql,name=data,mode=ReadWriteOnce,size=20Gi --set cpu=1,memory=1Gi,replicas=2

```

以上命令创建一套具有一主一从两个节点的PostgreSQL集群，PostgreSQL版本为8.0.33。

硬件配置为CPU为1核，内存1GB，数据盘20GB（/home/postgres/pgdata）

## 创建用户

```bash
$ $ kbcli cluster create-account mycluster --component postgresql --name dev --password dev
+----------+---------+
| RESULT   | MESSAGE |
+----------+---------+
| password | dev     |
+----------+---------+
```

为用户增加超级用户权限

```bash
$ kbcli cluster connect mycluster
postgres=# alter user dev with superuser;
ALTER ROLE
```


## 查询集群状态

```bash
$ kbcli cluster describe mycluster
Name: mycluster	 Created Time: Oct 24,2024 09:32 UTC+0800
NAMESPACE   CLUSTER-DEFINITION   VERSION             STATUS    TERMINATION-POLICY
postgresql       postgresql           postgresql-14.8.0   Running   Delete

Endpoints:
COMPONENT    MODE        INTERNAL                                            EXTERNAL
postgresql   ReadWrite   mycluster-postgresql.postgresql.svc.cluster.local:5432   172.18.3.182:5432
                         mycluster-postgresql.postgresql.svc.cluster.local:6432

Topology:
COMPONENT    INSTANCE                 ROLE      STATUS    AZ       NODE                           CREATED-TIME
postgresql   mycluster-postgresql-0   primary   Running   <none>   ceph04.dev1.lab/172.18.3.194   Oct 24,2024 09:32 UTC+0800

Resources Allocation:
COMPONENT    DEDICATED   CPU(REQUEST/LIMIT)   MEMORY(REQUEST/LIMIT)   STORAGE-SIZE   STORAGE-CLASS
postgresql   false       1 / 1                1Gi / 1Gi               data:20Gi      local-path

Images:
COMPONENT    TYPE         IMAGE
postgresql   postgresql   docker.io/apecloud/spilo:14.8.0-pgvector-v0.6.1

Data Protection:
BACKUP-REPO   AUTO-BACKUP   BACKUP-SCHEDULE   BACKUP-METHOD   BACKUP-RETENTION   RECOVERABLE-TIME

Show cluster events: kbcli cluster list-events -n postgresql mycluster
```

# 连接到PostgreSQL集群


## 开放PostgreSQL连接

```bash
$ kubectl expose svc mycluster-postgresql --name mycluster-postgresql-lb --type LoadBalancer --port 5432 --target-port 5432
```


## 连接到PostgreSQL

```bash
$ psql -h 172.18.3.182 -U dev -W  postgres
口令:
psql (16.4 (Homebrew), 服务器 14.11 (Ubuntu 14.11-1.pgdg22.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: 关闭)
输入 "help" 来获取帮助信息.

postgres=#
```


# 维护集群

## 实例扩容

实例扩容分为水平扩容和垂直扩容，不管哪种扩容目的就是提高整套集群的数据处理能力。

垂直扩容就是变更PostgreSQL集群中每个角色的CPU核数和内存容量大小。

水平扩容就是增加相同配置的从节点以增加集群的副本数量和只读能力。

### 垂直扩容

垂直扩容就是在不增加实例的前提下对每个现有实例进行CPU和内存大小的变更。

加入要把现有PostgreSQL集群实例配置更改为2核4GB配置，则进行如下操作

```bash
$ kbcli cluster vscale mycluster --components=postgresql --cpu=2 --memory=4G 
```

### 水平扩容

就是水平扩展相同配置的从节点。主从集群主节点只能有一个，可以扩容从节点的个数。

如果需要把当前集群设置为一主2从3副本的组织形式，就可以执行如下命令

```bash
$ kbcli cluster hscale mycluster --components=postgresql --replicas=3
```

## 切换主从角色

执行如下命令进行切换

```bash
$ kbcli cluster promote mycluster --instance='mycluster-postgresql-1'
```

如果集群只有2副本一主一从的形式就不用执行--instance参数.