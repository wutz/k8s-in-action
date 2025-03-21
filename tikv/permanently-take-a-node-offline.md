# 永久下线一个节点

本章节描述如何永久下线一个节点。

永久下线一个节点通常是更换整个服务器的情况。

下线节点需要注意如下几点：

1. 确保集群中有足够的存储空间容纳被下线节点的数据。
1. 下线节点会直接触发Region的迁移，请在集群不忙的时候进行。
1. 确认其他TiKV节点的状态是正常的。
1. 下线的操作根据需要迁移Region的数量和大小会耗时几分钟 至 数小时不等。

# 一、下线节点

下线节点前需要确认节点的信息，执行如下命令获取

```bash
# tiup cluster display tikv                                                                                                                                 tikv01.dev1.lab: Tue Nov 19 14:19:19 2024

Cluster type:       tidb
Cluster name:       tikv
Cluster version:    v8.1.1
Deploy user:        tikv
SSH type:           builtin
Dashboard URL:      http://172.19.12.1:2379/dashboard
Grafana URL:        http://172.19.12.1:3000
ID                Role        Host        Ports        OS/Arch       Status   Data Dir                    Deploy Dir
--                ----        ----        -----        -------       ------   --------                    ----------
...
172.19.12.1:20160  tikv        172.19.12.1  20160/20180  linux/x86_64  Up       /tikv/data/tikv-20160       /tikv/deploy/tikv-20160
```

假设要下线172.19.12.1:20160节点，执行如下命令

```bash
# tiup cluster scale-in tikv -N 172.19.12.1:20160

```

服务器下线的过程总节点的状态会经历Pending Offline -> Tombstone 两个阶段。

当节点达到Tombstone状态后，需要执行如下命令把节点真正从集群中删除。

```bash
# # tiup cluster prune tikv
+ [ Serial ] - SSHKeySet: privateKey=/root/.tiup/storage/cluster/clusters/tikv/ssh/id_rsa, publicKey=/root/.tiup/storage/cluster/clusters/tikv/ssh/id_rsa.pub
+ [Parallel] - UserSSH: user=tikv, host=172.19.12.1
...
+ [ Serial ] - FindTomestoneNodes
Will destroy these nodes: [172.19.12.1:20160]
Do you confirm this action? [y/N]:(default=N) y 输入y同意
``

上述命名完成后通过tiup cluster display tikv命令查看集群的状态，已经看不到被显现的节点

# 二、上线新节点

当有新服务器可以加入到该集群的时候，执行如下命令

这里假设新服务器的地址为172.18.12.5

这里与节点扩容的方式一致，先编写节点信息保存到scale-out-tikv.yaml文件中

```toml
tikv_servers:
  - host: 172.19.12.5
    resource_control:
      memory_limit: "64G"
      cpu_quota: "1600%"
```

执行如下命令进行节点的扩容

```bash
# tiup cluster scale-out tikv01 scale-out-tikv.yaml
```

如果上述命令输出没有报错可以执行如下命令确认节点是否已添加完成。

```bash
# tiup cluster display tikv
```