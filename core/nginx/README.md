# Ingress Nginx

> [Ingress-Nginx Controller](https://kubernetes.github.io/ingress-nginx/)

## 部署

修改 [patch.yaml](patch.yaml) 符合实际情况

```sh
kubectl apply -k .
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
kubectl delete -k .
```
