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

配置 DNS 解析到 Service Nginx 的 IP 上

```sh
# 输出的 EXTERNAL—IP 为需要 DNS 解析的 IP （如果环境使用一对一 NAT，需要解析到外网 IP)
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

后面示例假设配置 DNS 解析 `*.bj1a.example.com`

## 卸载

```sh
helmwave down
```
