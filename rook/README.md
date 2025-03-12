# [Rook Ceph](https://rook.io/)

## 准备

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
 
## 操作指南
 
- 修复 `ceph orch` 命令无法使用
  ```shell
  kubectl exec -it deployments/rook-ceph-tools -- bash
  ceph mgr module enable rook
  ceph orch set backend rook
  ceph orch status
  ```

## 部署 Operator

  ```sh
  kubectl apply -k operator/
  ```

## 部署 CephCluster

  根据实际情况修改 [cluster/patch.yaml](./cluster/patch.yaml) 中的 public 和 cluster 网段

  ```sh
  # 部署 CephCluster
  kubectl apply -k cluster/

  # 查看 CephCluster 状态
  kubectl get cephclusters

  # 查看 CephCluster 详细信息
  kubectl describe cephcluster rook-ceph
  ```

## [安装 kubectl-rook-ceph 用于运维](https://github.com/rook/kubectl-rook-ceph)

1. 安装 [krew](https://krew.sigs.k8s.io/docs/user-guide/setup/install/)
2. 安装 kubectl-rook-ceph 执行 `kubectl krew install rook-ceph`
3. 使用 `kubectl rook-ceph ceph -s` 命令查看集群状态

## 排错

* [查看 osd 数量是否符合预期](https://rook.io/docs/rook/latest-release/Troubleshooting/ceph-common-issues/?h=osd+prepare#solution_4)

  ```sh
  # 查看 osd 数量是否符合预期
  kubectl rook-ceph ceph osd tree
  kubectl get po -n rook-ceph

  # 查看 osd 准备日志，找到未加入 osd 原因
  kubectl -n rook-ceph get pod -l app=rook-ceph-osd-prepare
  kubectl -n rook-ceph logs rook-ceph-osd-prepare-xxx-xxx provision

  # 重启 operator 触发重新发现 osd
  kubectl rollout restart deployment rook-ceph-operator
  ```

  通常 osd 未加入是磁盘或者之前集群残留，参见 [销毁集群](#销毁集群) 章节

## [使用 Ceph Dashboard](https://rook.io/docs/rook/latest-release/Storage-Configuration/Monitoring/ceph-dashboard/)

通常不直接使用 Ceph Dashboard 管理集群而是使用 rook, Ceph Dashboard 作为一个 GUI 查看工具

```bash
kubectl port-forward svc/rook-ceph-mgr-dashboard 8443
```

访问 https://localhost:8443 即可, 用户名为 `admin`, 密码使用下面命令获取

```bash
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo
```

## [销毁集群](https://rook.io/docs/rook/latest-release/Getting-Started/ceph-teardown/)

```bash
# 销毁集群
kubectl rook-ceph destroy-cluster
# 输入 yes-really-destroy-cluster 后开始执行

# 删除 operator
kubectl delete -k operator/

# 删除宿主机残留
pdsh -w bj1sn[001-004] 'rm -rf /var/lib/rook'

# 抹除磁盘,下面方法任选其一
pdsh -w bj1sn[001-004] 'sgdisk --zap-all /dev/xxx'
pdsh -w bj1sn[001-004] 'dd if=/dev/zero bs=1M count=100 oflag=direct,dsync of=/dev/xxx'
# ssd 使用 blkdiscard 抹除而非 dd
pdsh -w bj1sn[001-004] 'blkdiscard /dev/xxx'
```