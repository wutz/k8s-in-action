# Cilium

> GA

提供 CNI，Service 和 Networking Policies 等功能

## 部署

修改 [values.yaml](values.yaml) 中的配置 `devices` 为实际的网卡名称

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