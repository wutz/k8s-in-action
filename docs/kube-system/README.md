# 调整核心服务 `coredns` 和 `metric-server` HA

```shell
kubectl patch deployment coredns -n kube-system --type merge --patch-file coredns-patch.yaml

kubectl patch deployment metrics-server -n kube-system --type merge --patch-file metrics-server-patch.yaml
```
