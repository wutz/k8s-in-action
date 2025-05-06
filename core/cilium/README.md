# Cilium

提供 CNI，Service 和 Networking Policies 等功能

## 部署

修改 [values.yaml](values.yaml) 中的配置 `k8sServiceHost` 和 `k8sServicePort` 为 API Server 的地址和端口

```sh
# 部署 helm
helmwave up --build

# 等待所有 pod 就绪
kubectl wait -n kube-system --for=condition=ready pod -l app.kubernetes.io/part-of=cilium
```

## 卸载

```sh
helmwave down
```