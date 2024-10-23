# Ingress Nginx

> [Ingress-Nginx Controller](https://kubernetes.github.io/ingress-nginx/)

k3s 缺省安装 traefik 适合大部分场景, 本指南改用更习惯 Nginx

## 部署

```sh
# 创建 values.yml
cat << 'EOF' > values.yml
controller:
  # 指定 Nginx 副本数
  replicaCount: 2
  ingressClassResource:
    # 指定 Nginx 为缺省 Ingress
    default: true
  service:
    annotations:
      # 指定 Service Load Balancer 的 IP, 防止意外重建时 IP 变化
      metallb.universe.tf/loadBalancerIPs: 10.128.0.100
  # 指定 Nginx 优先运行在管理节点上
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 50 
          preference:
            matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists  
  # 指定 Nginx 容忍管理节点上的污点
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
EOF

# 部署
helmwave up --build
```

配置 DNS 解析到 Service Nginx 的 IP 上 (需要联系 DNS 管理员配置解析)

```sh
# 获取 Service Nginx 的 EXTERNAL-IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

* 从上述获取到为内网 IP `10.128.0.100`, 则解析 `*.bj1a-int.example.com` 到 `10.128.0.100`
* 如果上述 IP 配置外网一对一 NAT，例如 `1.2.3.4`, 则解析 `*.bj1a.example.com` 到 `1.2.3.4`
* 如果上述 IP 为外网 IP， 例如 `1.2.3.4`, 则解析 `*.bj1a.example.com` 到 `1.2.3.4`

## 卸载

```sh
helmwave down
```
