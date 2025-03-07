# [Rook Ceph](https://rook.io/)

- 至少 3 台机器，每台至少插入 1 块本地盘
- 推荐额外配置 1 条网络用于集群内数据复制, 可以极大提升存储性能
  - 如果只有 1 条网络，则移除 `rook-ceph-cluster` 配置中的 `cephClusterSpec.network`
  - 如果有 2 条网络，根据实际的宿主机网络设置 `public` 和 `cluster` 网段
- 为存储节点打上额外 label, 下面使用 3 台 mn 节点复用作为存储节点
  ```sh
  kubectl label node mn01.play.local role=storage-node
  kubectl label node mn02.play.local role=storage-node
  kubectl label node mn03.play.local role=storage-node
  ```
- 部署 Rook

  ```sh
  helmwave up --build

  # 进入 toolbox 中，执行 ceph 常用命令
  k exec -it rook-ceph-tools-xxxxx-xxx -- bash
  ```

- 使用 pvc 时，可以指定以下 3 个 storageClass
  - ceph-block
  - ceph-filesystem
  - ceph-bucket
 
## 操作指南

- 注意检查磁盘上存在分区。 如果存在分区，需要尝试执行如下命令清除分区表（在宿主机上执行）

  ```
  以下三个命令根据自己的环境可以任选其一进行尝试，dd和sgdisk抹除的最彻底
  # dd if=/dev/zero of=/dev/xxx bs=1M count=1
  # wipefs -fa /dev/sda
  # sgdisk --zap-all /dev/sda
  ```

  - 如果依然还存在分区，使用 `dmsetup remove /dev/mapper/ceph--xxx` 清除分区（在宿主机上执行）

- 主动触发重新扫描OSD

  ```shell
  kubectl -n rook-ceph rollout restart deployment rook-ceph-operator
  ```

- 查看ceph cluster状态

  ```
  kubectl -n rook-ceph get cephclusters.ceph.rook.io
  NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH      EXTERNAL   FSID
  rook-ceph   /var/lib/rook     3          52m   Ready   Cluster created successfully   HEALTH_OK              f6e0c207-33d4-4329-b1fb-29e502b79277
  ```

  - 如果卸载rook后有残留未清理，可以尝试清理宿主机 `DATADIRHOSTPATH` 目录
