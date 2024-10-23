# [MetalLB](https://metallb.universe.tf/)

k3s 缺省安装的是 [ServiceLB](https://docs.k3s.io/zh/networking/networking-services#service-load-balancer), 其为每个 Service 在所有节点启动一个 Pod，这个 Pod 通过 iptables 将流量从 Host 转换到 Service ClusterIP 上。这也造成缺省安装 k3s 的 80 & 443
被占用，但是通过 `netstat -tunlp` 又查询不到。ServiceLB 比较适合无需要 HA 支持场景。

对于需要 HA 支持场景，可以使用 MetalLB 替代。


## 部署

```sh
# 部署 metallb
helmwave up --build
```

```sh
# 创建 default pool 用于为 Service LoadBalancer 分配 IP 地址
# 参考 https://metallb.universe.tf/configuration/
cat << 'EOF' > default-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb
spec:
  addresses:
    # 从数据中心管理员获取空闲 IP 地址池
    - 10.128.0.100-10.128.0.199
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb
spec:
  ipAddressPools:
    # 指定上述 IPAddressPool 名字
    - default
  nodeSelectors:
    # 指定上述 IPAddressPool 网络可达的节点
    - matchLabels:
        node-role.kubernetes.io/control-plane: "true"
  interfaces:
    # 指定上述 IPAddressPool 网络可达的节点网卡
    - eth0
EOF

# 创建 default pool
kubectl apply -f default-pool.yaml
```


```sh
# 使用示例
# 参考 https://metallb.universe.tf/usage/ 
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    # 指定 IP 地址池中的 IP 地址, 该 IP 地址必须在此 IPAddressPool 中
    # 设置此注解可以防止 Service 重建时 IP 地址发生变化
    metallb.universe.tf/loadBalancerIPs: 10.128.0.100
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
EOF
```

## 卸载

```sh 
# 删除 default pool
kubectl delete -f default-pool.yaml
```

```sh
# 卸载 metallb
helmwave down
```
