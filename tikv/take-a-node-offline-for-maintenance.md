# 临时维护tikv节点

本章节描述在发生节点维护需要临时下线的场景如何使用tiup进行操作。

需要临时下线的场景包括：

1. 服务器硬件故障需要厂商维修。
1. 服务器网络故障需要临时调整。

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

假设需要临时维护的节点IP为172.19.12.1，执行如下命令

```bash
# tiup cluster stop tikv --node 172.19.12.1:20160
```

执行完上述命令后会按照TiDB、TiKV、PD的顺序停止节点。

停止过程中会先把节点标记为Offline状态。

以上命令本身不会直接触发Region的重新平衡

目标节点停止后，PD会自动将目标节点标记为Disconnect状态，PD会尝试将Region迁移到其他节点。

# 二、恢复节点

当节点维护完成需要上线，执行如下命令

```bash
# tiup cluster start tikv --node 172.19.12.1:20160
```

当使用如上命令启动节点后，PD会重新评估集群状态。

如果发现Region分布不均衡时，才会触发真正的Region重平衡。
