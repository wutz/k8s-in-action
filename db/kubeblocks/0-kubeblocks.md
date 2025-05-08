# 简介

KubeBlocks 是基于 Kubernetes 的云原生数据基础设施，将顶级云服务提供商的大规模生产经验与增强的可用性和稳定性改进相结合，帮助用户轻松构建容器化、声明式的关系型、NoSQL、流计算和向量型数据库服务。

KubeBlocks 的名字源自 Kubernetes（K8s）和乐高积木，致力于让 K8s 上的数据基础设施管理就像搭乐高积木一样，既高效又有趣。

KubeBlocks 引入了 ReplicationSet 和 ConsensusSet，具备以下能力：

1. 基于角色的更新顺序可减少因升级版本、缩放和重新启动而导致的停机时间。
1. 维护数据复制的状态，并自动修复复制错误或延迟。

KubeBlocks主要功能：

1. 支持多云，与 AWS、GCP、Azure、阿里云等云平台兼容。
1. 支持 MySQL、PostgreSQL、Redis、MongoDB、Kafka 等 32 个主流数据库和流计算引擎。
1. 提供生产级性能、弹性、可扩展性和可观察性。
1. 简化 day-2 操作，例如升级、扩展、监控、备份和恢复。
1. 包含强大且直观的命令行工具。
1. 仅需几分钟，即可建立一个适用于生产环境的完整数据基础设施


# 环境准备

在开始之前，请确保已经满足以下条件。

系统最低要求：

CPU：4 核
RAM：4 GB

在电脑上已安装：

kubectl：用于与 Kubernetes 集群进行交互；
kbcli：用于 Playground 和 KubeBlocks 之间的交互。
Kubernetes: 一套可用的Kubernetes集群。

## 安装kbcli

执行如下命令安装kbcli

```bash
$ curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash -s 0.9.1

```

## 安装KubeBlocks

执行如下命令安装KubeBlocks

```bash
$ kbcli kubeblocks install
```

默认情况下被安装的KubeBlocksde 版本与kbcli版本一一对应，所以这里安装的KubeBlocks版本也为0.9.1
