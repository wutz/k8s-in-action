# 集群元数据备份和恢复

使用K3S搭建的Kubernetes集群默认使用etcd保存元数据信息。

本章节介绍如何基于etcd进行Kubernetes集群元数据的备份和恢复。

# 备份

K3S默认开启快照备份，备份时间为每天的00:00和12:00。系统会始终保留5个最近由系统自动触发的快照备份数据。

默认情况下K3S快照保存在/var/lib/rancher/k3s/server/db/snapshots目录下

```bash
root@mn01:~# cd /var/lib/rancher/k3s/server/db/snapshots
root@mn01:/var/lib/rancher/k3s/server/db/snapshots# ls
etcd-snapshot-mn01.dev1.local-1729310405  etcd-snapshot-mn01.dev1.local-1729440002  on-demand-mn01.dev1.local-1729149615
etcd-snapshot-mn01.dev1.local-1729353601  etcd-snapshot-mn01.dev1.local-1729483202  on-demand-mn01.dev1.local-1729150013
etcd-snapshot-mn01.dev1.local-1729396804  on-demand-mn01.dev1.local-1729149154
```

如上图所示，所有etcd-snapshot开头的快照都是系统自动触发的快照；on-demand开头的快照都是手工执行相关命令创建的快照。

系统会始终保留5个最近自动触发的快照数据；手工创建的备份数据不会被自动删除，需要手工删除。

如果你的Kubernetes集群有多个etcd,master节点，每个节点都会在00:00和12:00自动触发快照备份。

## 手工触发备份

执行如下命令手工触发备份

```bash
root@mn01:/var/lib/rancher/k3s/server/db/snapshots# k3s etcd-snapshot save
INFO[0000] Snapshot on-demand-mn01.dev1.local-1729494108 saved.
```

如果输出有部分警告信息，可以忽略掉

以上命令新生成了一份快照备份数据 on-demand-mn01.dev1.local-1729494108

K3S的快照备份不仅支持本地备份，还支持将备份数据保存在S3存储上。详见官方文档

```html
https://docs.k3s.io/cli/etcd-snapshot
```

因为集群具有3个主节点并且每个主节点都保持5份备份数据，就不需要依赖外部备份机制再实现数据的冗余备份。

# 恢复

本章节基于两个实际场景说明如何进行集群的恢复

## 基于主节点mn01恢复

本章节描述如何使用mn01节点的快照备份恢复整个集群。

以下操作请在root用户环境下进行。

### 所有主节点关闭k3s服务

请在mn[01-03]节点执行如下命令关闭k3s服务

```bash
# systemctl stop k3s
```

### mn01节点执行数据恢复

此步骤需要先确认需要恢复到的快照备份文件，通常选择一个最新的快照备份。

```bash
# k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/etcd-snapshot-mn01.dev1.local-1729483202
```

### 备份和删除源数据目录

请在mn[01-03]节点执行如下命令,备份和删除/var/lib/rancher/k3s/server/db目录

```bash
# cd /var/lib/rancher/k3s/server/
# mv db db.20241021
```

### mn01节点启动k3s服务

```bash
# systemctl start k3s
```

### mn[02-03]节点从新加入到新集群

以下步骤需要依次在mn[02-03]节点上执行

```bash
# systemctl start k3s
```

### gn001节点重新加入新集群

```bash
# systemctl restart k3s-agent
```

## 基于主节点mn02恢复

本章节假设mn01节点的备份数据被手工误删除，如何使用mn02节点的快照备份恢复整个集群。同样mn03节点的备份也适用于该场景

以下操作请在root用户环境下进行。

### 所有主节点关闭k3s服务

请在mn[01-03]节点执行如下命令关闭k3s服务

```bash
# systemctl stop k3s
```

### 把mn02的备份数据同步到mn01节点

请在mn02上执行如下操作,执行前请先确认mn02和mn01已经做过ssh互信。

```bash
# rsync -avoPg /var/lib/rancher/k3s/server/db/snapshots/etcd-snapshot-mn01.dev1.local-1729483202 mn01:/tmp/etcd-snapshot-mn01.dev1.local-1729483202
```

### mn01节点执行数据恢复

此步骤需要先确认需要恢复到的快照备份文件，通常选择一个最新的快照备份。

```bash
# k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/etcd-snapshot-mn01.dev1.local-1729483202
```

### 备份和删除源数据目录

请在mn[01-03]节点执行如下命令,备份和删除/var/lib/rancher/k3s/server/db目录

```bash
# cd /var/lib/rancher/k3s/server/
# mv db db.20241021
```

### mn01节点启动k3s服务

```bash
# systemctl start k3s
```

### mn[02-03]节点从新加入到新集群

以下步骤需要依次在mn[02-03]节点上执行

```bash
# systemctl start k3s
```

### gn001节点重新加入新集群

```bash
# systemctl restart k3s-agent
```
