# K8S 实战

搭建一套面向 AI 生产可用 K8S 集群

## 基础

目前 K8S 主流发行版本有 [k0s](https://docs.k0sproject.io/stable/), [k3s](https://k3s.io/), [k8s](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) 和 [eks](https://distro.eks.amazonaws.com/) 可以选择一个偏好的，本实战项目是基于 k3s：

1. [准备](docs/0-prepare.md)
2. [安装 k3s](docs/1-k3s.md)
3. [常用客户端](docs/2-tools.md)
4. [备份和恢复](docs/3-backup-restore.md)

## 核心

部署用于 [核心](core/) 网络和存储等组件

## AI

部署用于 [AI](ai/) 相关计算服务

## 可观测性

1. [部署 Metric 监控 VictoriaMetrics](vm/README.md)
2. 部署日志监控 Loki

## 服务

* 部署 [Harbor](harbor/) 提供容器镜像服务
* 部署 [PyPI](pypi/) 提供镜像服务
* 部署 [Conda](conda/) 提供镜像服务

## 数据库

部署 [数据库](db/) 服务

## 存储

部署 [存储](storage/) 服务

