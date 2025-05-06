# [nfd](https://github.com/kubernetes-sigs/node-feature-discovery)

检测硬件特性并相应地标记节点，以便用于调度决策。 通常被 gpu-operator 和 network-operator 等工具使用。

## 部署

修改 [instance-type.yaml](./instance-type.yaml) 以符合实际情况

```bash
helmwave up --build

# 等待 Pod 启动
kubectl wait --namespace nfd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=nfd \
  --timeout=120s
```
