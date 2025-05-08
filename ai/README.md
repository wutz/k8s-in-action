# AI

提供 AI 相关计算支持功能

## 基础

1. 部署 [nfd](nfd/) 用于提供硬件特性检测服务, 并将其作为 Label 附加到节点上
2. 部署 [gpu-operator](gpu-operator/) 用于支持 GPU 设备
3. 部署 [network-operator](network-operator/) 用于支持 Infiniband/RoCE 设备

## 训练

1. 部署 [mpi-operator](mpi-operator/) 用于提供 MPI 分布式训练服务
2. 部署 [train-operator](train-operator/) 用于提供 Pytorch 等分别训练服务

## 推理

1. 部署 lws 用于分布式推理
2. 部署 [ollama](ollama/) 用于提供 Ollama+OpenWebUI 轻量推理服务

## 性能测试

* [nccl-tests](nccl-tests/) 用于测试 NCCL 性能
* nvbandwidth 用于 Host(CPU) 与 Device(GPU) 间内存带宽测试, 以及 Device(GPU) 间内存带宽测试

