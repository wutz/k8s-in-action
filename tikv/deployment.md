# 部署 TiKV 集群

TiKV 相比 Redis 更适合作为分布式 KV 存储，支持分布式事务，数据一致性更高。

## [软硬件配置](https://docs.pingcap.com/zh/tidb/stable/hardware-and-software-requirements)

* 节点数量：至少 3 台
* 操作系统：Ubuntu 22.04
* 组件资源配置：
    * PD：8 核+，16GB+，SSD，万兆网络+，3 实例
    * TiKV：16 核+，64GB+，SSD，万兆网络+，3 实例
    * 监控：8 核+，16GB+，SAS，千兆网络+，1 实例
    > * PD 和 TiKV 可运行同一节点
    > * TiKV 硬盘配置 NVMe SSD 不超过 4 TB, SAS SSD 不超过 1.5 TB

## [系统配置](https://docs.pingcap.com/zh/tidb/stable/check-before-deployment)

执行 [准备节点](../docs/0-prepare.md)

配置内核参数

```bash
cat << EOF > 99-tikv.conf
vm.swappiness = 0
net.ipv4.tcp_syncookies = 0
fs.nr_open  = 20000000
fs.file-max = 40000000
vm.max_map_count = 5642720
EOF
pdcp -w ^all 99-tikv.conf /etc/sysctl.d/
pdsh -w ^all sysctl --system
```

安装 numactl

```bash
pdsh -w ^all apt install numactl -y
```

格式化和挂载磁盘设备

```bash
pdsh -w ^all mkfs.ext4 /dev/nvme0n1
pdsh -w ^all e2label /dev/nvme0n1 tikv
pdsh -w ^all mkdir -p /tikv
pdsh -w ^all cp /etc/fstab /etc/fstab.bak
pdsh -w ^all echo "LABEL=tikv /tikv ext4 defaults,nodelalloc,noatime 0 2" >> /etc/fstab
pdsh -w ^all mount -a
```

## 部署与启动

### [使用 TiUP 部署 TiKV 集群](https://docs.pingcap.com/zh/tidb/stable/production-deployment-using-tiup)

```bash
# 安装 TiUP
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source ~/.bashrc
which tiup
# 安装 TiUP Cluster 组件
tiup cluster

# 配置 topology.yaml
cat << EOF > topology.yaml
global:
  user: "tikv"
  ssh_port: 22
  deploy_dir: "/tikv/deploy"
  data_dir: "/tikv/data"
  listen_host: 0.0.0.0
  arch: "amd64"
  enable_tls: true
  resource_control:
    memory_limit: "16G"
    cpu_quota: "800%"

pd_servers:
  - host: 172.19.12.1
  - host: 172.19.12.2
  - host: 172.19.12.3

tikv_servers:
  - host: 172.19.12.1
    resource_control:
      memory_limit: "64G"
      cpu_quota: "1600%"
  - host: 172.19.12.2
    resource_control:
      memory_limit: "64G"
      cpu_quota: "1600%"
  - host: 172.19.12.3
    resource_control:
      memory_limit: "64G"
      cpu_quota: "1600%"

monitored:
  node_exporter_port: 9200

monitoring_servers:
  - host: 172.19.12.1

grafana_servers:
  - host: 172.19.12.1
EOF

# 检查集群存在的潜在风险
tiup cluster check ./topology.yaml --user root
# 自动修复集群存在的潜在风险
tiup cluster check ./topology.yaml --user root --apply

# 部署 TiKV 集群
tiup cluster deploy tikv01 v8.1.2 ./topology.yaml --user root
# 查看集群状态
tiup cluster list
# 查看集群详情
tiup cluster display tikv01

# 启动集群
tiup cluster start tikv01
# 查看集群状态, 输出包含 tls 文件路径用于客户端访问时使用
tiup cluster display tikv01

```

### 使用 TiDB Operator 部署 TiKV 集群

> 🚧️ 正在施工中
