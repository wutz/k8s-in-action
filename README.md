# k8s-in-action

搭建一套生产可用 K8S 集群

## 目录

0. [准备](docs/0-prepare.md)
1. [安装 k3s](docs/1-k3s.md)
2. [使用常用客户端工具 kubectl + kustomize + helm/helmwave](docs/2-tools.md)
3. [部署存储 Rook + NFS CSI]
4. [部署入口网络 MetalLB + Nginx Ingress + CertManager]
5. [部署 Metric 监控 VictoriaMetrics + Grafana]
6. [部署 GPU 支撑服务 GPU Operator]
7. [运行 Ollama + Open WebUI 推理服务]
8. [部署训练支撑服务 MPI Operator]
9. [运行 nccl-tests]

## 未来

1. [部署日志监控 Loki]
2. [部署 Serverless 服务 KNative]
3. [部署推理服务 KServe + vLLM]
4. [部署训练服务 Training Operator]
