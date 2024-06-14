# Rook (Ceph)

> https://rook.io/

- 至少 3 台机器，每台至少插入 1 块本地盘
- 推荐额外配置 1 条网络用于集群内数据复制, 可以极大提升存储性能
  - 如果只有 1 条网络，则移除 `rook-ceph-cluster` 配置中的 `cephClusterSpec.network`
  - 如果有 2 条网络，根据实际的宿主机网络设置 `public` 和 `cluster` 网段
- 为存储节点打上额外 label, 下面使用 3 台 mn 节点复用作为存储节点
  ```sh
  k label node mn01.play.local role=storage-node
  k label node mn02.play.local role=storage-node
  k label node mn03.play.local role=storage-node
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
