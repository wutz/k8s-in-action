# apiserver-lb

用于对外提供 API Server 负载均衡服务

## 部署

修改 [service.yaml](service.yaml) 中的 IP 地址

```sh
kubectl apply -k .
```

## 使用

修改本地的 `kubeconfig` 文件中的 `server` 字段为 `apiserver-lb` 的 vip 地址

## 卸载

```sh
kubectl delete -k .
```

