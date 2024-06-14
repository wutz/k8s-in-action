# k8s-in-action

搭建一套生产可用 K8S 集群

## 目录

### 基础

0. [准备](docs/0-prepare.md)
1. [安装 k3s](docs/1-k3s.md)
2. [使用常用客户端工具 kubectl + kustomize + helm/helmwave](docs/2-tools.md)

### 存储

k3s 缺省安装 local-path 存储，适合缓存数据或者支持 HA 的数据库使用。

如果需要持久存储，不需要 HA 支持的情况下可以使用 NFS，需要 HA 支持可以使用 Rook (Ceph)。

多个存储可以同时并存。

3. [部署存储 NFS CSI](nfs-csi/README.md)
4. [部署存储 Rook (Ceph)]

### 网络

5. [部署入口网络 MetalLB + Nginx Ingress + CertManager]

### 监控

6. [部署 Metric 监控 VictoriaMetrics + Grafana]

### AI

7. [部署 GPU 支撑服务 GPU Operator]
8. [运行 Ollama + Open WebUI 推理服务]
9. [部署训练支撑服务 MPI Operator]
10. [运行 nccl-tests]

## 未来

1. [部署日志监控 Loki]
2. [部署 Serverless 服务 KNative]
3. [部署推理服务 KServe + vLLM]
4. [部署训练服务 Training Operator]
