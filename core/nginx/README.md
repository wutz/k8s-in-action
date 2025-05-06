# Ingress Nginx

提供 Ingress 服务

## 部署

修改 [values.yaml](values.yaml) 中的配置 `controller.service.loadBalancerIP` 为 Service Nginx 的 IP 地址

```sh
helmwave up --build

# 等待 Ingress-Nginx 启动
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

配置 DNS 解析到 Service Nginx 的 IP 上 (需要联系 DNS 管理员配置解析)

```sh
# 获取 Service Nginx 的 EXTERNAL-IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

* 从上述获取到为内网 IP `172.18.15.198`, 则解析 `*.bj1i.example.com` 到 `10.128.0.100`
* 如果上述 IP 配置外网一对一 NAT，例如 `1.2.3.4`, 则解析 `*.bj1.example.com` 到 `1.2.3.4`
* 如果上述 IP 为外网 IP， 例如 `1.2.3.4`, 则解析 `*.bj1.example.com` 到 `1.2.3.4`

## 卸载

```sh
helmwave down
```
