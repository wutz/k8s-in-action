# [Rook Ceph](https://rook.io/)

- 至少 3 台机器，每台至少插入 1 块本地盘
- 推荐额外配置 1 条网络用于集群内数据复制, 可以极大提升存储性能
  - 如果只有 1 条网络，则移除 `rook-ceph-cluster` 配置中的 `cephClusterSpec.network`
  - 如果有 2 条网络，根据实际的宿主机网络设置 `public` 和 `cluster` 网段
- 为存储节点打上额外 label, 下面使用 3 台 mn 节点复用作为存储节点
  ```sh
  kubectl label node bj1sn001 node-role.kubernetes.io/storage=true
  kubectl label node bj1sn002 node-role.kubernetes.io/storage=true
  kubectl label node bj1sn003 node-role.kubernetes.io/storage=true
  kubectl label node bj1sn004 node-role.kubernetes.io/storage=true
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
  # dd if=/dev/zero of=/dev/xxx bs=1M count=1
  sgdisk --zap-all /dev/xxx
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

  - 如果卸载rook后有残留未清理，可以尝试清理宿主机 `DATADIRHOSTPATH: /var/lib/rook` 目录
 
- 修复 `ceph orch` 命令无法使用
  ```shell
  kubectl exec -it deployments/rook-ceph-tools -- bash
  ceph mgr module enable rook
  ceph orch set backend rook
  ceph orch status
  ```
  
  

- 部署 Operator
  ```sh
  kubectl apply -k operator/
  ```

- 部署 CephCluster
  根据实际情况修改 [cluster/patch.yaml](./cluster/patch.yaml) 中的 public 和 cluster 网段
  ```sh
  # 部署 CephCluster
  kubectl apply -k cluster/

  # 查看 CephCluster 状态
  kubectl get cephclusters
  # 查看 CephCluster 详细信息
  kubectl describe cephcluster rook-ceph
  ```

# [安装 kubectl-rook-ceph 用于运维](https://github.com/rook/kubectl-rook-ceph)

1. 安装 [krew](https://krew.sigs.k8s.io/docs/user-guide/setup/install/)
2. 安装 kubectl-rook-ceph 执行 `kubectl krew install rook-ceph`
3. 使用 `kubectl rook-ceph ceph -s` 命令查看集群状态

# 排错

* [查看 osd 数量是否符合预期](https://rook.io/docs/rook/latest-release/Troubleshooting/ceph-common-issues/?h=osd+prepare#solution_4)

  ```sh
  kubectl rook-ceph ceph osd tree
  kubectl get po -n rook-ceph
  ```

# 销毁集群

```bash
kubectl rook-ceph destroy-cluster
# 输入 yes-really-destroy-cluster 后开始执行

pdsh -w bj1sn[001-004] 'rm -rf /var/lib/rook'
```