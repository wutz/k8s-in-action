# 创建并使用MySQL集群

本文档描述如何通过kbcli命令在Kubernetes集群内创建一套MySQL集群。

# 创建步骤

## 创建命名空间

执行如下命令创建MySQL集群专用命名空间。

```bash
$ kubectl create ns mysql
```

## 确认可安装的MySQL版本

执行如下步骤确认可安装的MySQL版本

```bash
$ kbcli clusterversion list |grep mysql
NAME                 CLUSTER-DEFINITION   STATUS      IS-DEFAULT   CREATED-TIME
ac-mysql-8.0.30      apecloud-mysql       Available   true         Oct 21,2024 18:07 UTC+0800
ac-mysql-8.0.30-1    apecloud-mysql       Available   false        Oct 21,2024 18:07 UTC+0800
mysql-5.7.44         mysql                Available   false        Oct 21,2024 18:07 UTC+0800
mysql-8.0.33         mysql                Available   true         Oct 21,2024 18:07 UTC+0800
mysql-8.4.2          mysql                Available   false        Oct 21,2024 18:07 UTC+0800
```

这里建议选择NAME为mysql开头的版本，可以看到默认0.9.1版本的KubeBlocks目前提供了5.7.44、8.0.33和8.4.2三个MySQL版本。

## 创建单机版集群

单机版集群就是启动一个MySQL实例，该实例不具备主备切换的功能。

即将被创建的MySQL集群名称为mycluster

```bash
$ kbcli cluster create mycluster --cluster-definition mysql --cluster-version mysql-8.0.33 --pvc type=mysql,name=data,mode=ReadWriteOnce,size=20Gi --set cpu=1,memory=1Gi,replicas=1
```

以上命令创建一个单节点的MySQL集群，MySQL版本为8.0.33。

## 创建主备集群

主备复制集群会启动一主一从实例，当主出现故障的时候自动切换。

即将被创建的MySQL集群名称为mycluster

```bash
$ kbcli cluster create mycluster --cluster-definition mysql --cluster-version mysql-8.0.33 --pvc type=mysql,name=data,mode=ReadWriteOnce,size=20Gi --set cpu=1,memory=1Gi,replicas=2

```

## 创建用户

```bash
$ $ kbcli cluster create-account mycluster --component mysql --name dev --password dev
+----------+---------+
| RESULT   | MESSAGE |
+----------+---------+
| password | dev     |
+----------+---------+
```

## 创建集群状态

```bash

```

# 连接到MySQL集群


## 开放MySQL连接

```bash
$ kubectl expose svc mycluster-mysql --name mycluster-mysql-lb --type LoadBalancer --port 3306 --target-port 3306
```

## 连接到MySQL

```bash
$ mysql -h 172.18.3.182 -udev -pdev
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 670
Server version: 8.0.33 MySQL Community Server - GPL

Copyright (c) 2000, 2023, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| performance_schema |
+--------------------+
2 rows in set (0.02 sec)

mysql>
```


# 维护集群

## 实例扩容

实例扩容就是变更MySQL集群中每个角色的CPU核数和内存容量大小。

### 垂直扩容

垂直扩容就是在不增加实例的前提下对每个现有实例进行CPU和内存大小的变更。

加入要把现有MySQL集群实例配置更改为2核4GB配置，则进行如下操作

```bash
$ kbcli cluster vscale mycluster --components=mysql --cpu=2 --memory=4Gi 
```

### 水平扩容

就是水平扩展相同配置的从节点。主从集群主节点只能有一个，可以扩容从节点的个数。

如果需要把当前集群设置为一主2从3副本的组织形式，就可以执行如下命令

```bash
$ kbcli cluster hscale mycluster --components="mysql" --replicas=3
```

## 切换主从角色

执行如下命令进行切换

```bash
$ kbcli cluster promote mycluster --instance='mycluster-mysql-1'
```

如果集群只有2副本一主一从的形式就不用执行--instance参数.