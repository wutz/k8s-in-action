# 负载均衡 MetalLB

k3s 缺省安装的是 [ServiceLB](https://docs.k3s.io/zh/networking/networking-services#service-load-balancer), 其为每个 Service 在所有节点启动一个 Pod，这个 Pod 通过 iptables 将流量从 Host 转换到 Service ClusterIP 上。这也造成缺省安装 k3s 的 80 & 443
被占用，但是通过 `netstat -tunlp` 又查询不到。ServiceLB 比较适合无需要 HA 支持场景。

对于需要 HA 支持场景，可以使用 MetalLB 替代。虽然 K8S 支持多种 Service Load Balancer 并存，但是一般简化使用，故而关闭 ServiceLB 功能。

- 关闭 ServiceLB

  ```sh
  # 关闭 k3s 自带的 ServiceLB
  pdsh -w ^server "sed -i '/token:/a disable:\n- servicelb' /etc/rancher/k3s/config.yaml"
  pdsh -w ^server systemctl restart k3s
  ```

- 安装 MetalLB

  ```sh
  helmwave up --build

  # 缺省 service traefik 会申请走 ip
  k get svc traefik -n kube-system
  ```

  上述步骤完成：

  - 部署 metallb chart
  - 部署一个 IPAddressPool 和 L2Advertisement
    - 其 IPAddressPool 中的 IP 来自网络管理员分配
      - 如果只面向内部访问，填入空闲的私有 IP 即可
      - 如果面向外部访问, 填入分配的公网 IP 即可。在有些环境下配置了一对一 NAT 填入分配的私有 IP
    - L2Advertisement 中要限制为上述 IP 网络可达的节点列表
