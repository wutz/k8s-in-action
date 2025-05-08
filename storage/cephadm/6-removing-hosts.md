# 移除指定主机

本文档参考如下文档： https://www.ibm.com/docs/en/storage-ceph/7?topic=installation-removing-hosts

## 获取主机详情

执行如下命令获取主机列表

```bash
# ceph orch host ls
HOST      ADDR        LABELS                         STATUS  
...
bj1sn004	10.11.62.8                           
...
```

## 移除主机上的daemon

本文档以移除bj1sn004节点为例，执行如下命令。

```bash
# ceph orch host drain bj1sn004
```

查看主机移除状态

```bash
# ceph orch host ls
HOST      ADDR        LABELS                         STATUS  
...
bj1sn004	10.11.62.8        _no_schedule,_no_conf_keyring                    
...
_no_schedule标签会自动应用在即将下线的节点上。
```

```bash
# ceph -s
可以看到ceph集群会处于recovering状态直到osd服务全部下线完成。
完成后osd数量已经变更为目标值。
```

```bash
# ceph orch ps bj1sn004
No daemons reported
确认是否还有daemon在运行
```

## 完全移除主机

```bash
# ceph orch rm bj1sn004
```

