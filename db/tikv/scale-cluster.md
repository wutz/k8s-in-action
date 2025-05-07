# 1. 集群扩缩容

本文档默认描述的是tikv服务的扩容。

## 1.1. 集群扩容

tikv服务的扩容当前描述的是tikv的横向扩容。

横向扩容就是新增服务器节点，横向增加tikv的总容量和处理能力。

约定当前tikv集群使用tiup命令行工具部署。

### 1.1.1. 编写新节点配置文件

假设新加一个节点172.18.12.4，则这个新节点的配置如下所示

```toml
tikv_servers:
  - host: 172.19.12.4
    resource_control:
      memory_limit: "64G"
      cpu_quota: "1600%"
```

把上面信息保存成一个新的文件，这里约定文件名称为scale-out-tikv.toml。

在主节点上执行如下命令将tikv服务部署到新节点。

本文档假设172.18.12.1节点为主节点，以下操作全在该节点上执行

```bash
# tiup cluster scale-out tikv01 scale-out-tikv.yaml
```

如果上述命令输出没有报错可以执行如下命令确认节点是否已添加完成。

```bash
# tiup cluster display tikv
```

以上命令执行完成后会看到指定节点已经加入到tikv集群。

## 1.2. 集群缩容

执行如下命令把store置为tombstone状态，该状态节点可以移除

这里假设172.18.12.4节点加入到tikv集群后其store_id = 40。如果要下线该节点就需要执行如下命令

```bash
# tiup ctl:v8.1.1 pd --pd 127.0.0.1:2379 store delete 40
```

命令执行完成后通过如下命令查看节点状态

```bash
# tiup cluster display tikv
```

以上命令会显示当前tikv集群是否可以下线指定节点，如果提示使用prune清理节点信息就可以执行下面的prune命令

172.18.12.4节点状态会发生如下变化 UP -> Offline -> Tombstone。

执行如下命令确认没有region再使用刚刚下线的store

```bash
# tiup ctl:v8.1.1 pd --pd 127.0.0.1:2379 region --jq=.regions[] | {id,peers}
```

清除tombstone的节点

```bash
# tiup cluster prune tikv
```

