# K3S

准备用于 pdsh 的节点列表

```sh
cat << 'EOF' > server
bj1mn[01-03]
EOF

cat << 'EOF' > agent
bj1gn[001-003]
EOF
```

## 安装 k3s

生成 token, 替换下面配置文件中的 <token>

```sh
echo $(tr -dc a-z0-9 </dev/urandom | head -c 32)
zhhbdjwwite7o0wtbu1pxowqqod15bwu
```

> zhhbdjwwite7o0wtbu1pxowqqod15bwu 为示例，请替换为自己的 token

### 安装 k3s server

```sh
# 准备 scheduler 配置文件, 用于调度优先填满一个 GPU 节点
cat << 'EOF' > scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/rancher/k3s/k3s.yaml
profiles:
- pluginConfig:
  - args:
      scoringStrategy:
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
        - name: nvidia.com/gpu
          weight: 3
        type: MostAllocated
    name: NodeResourcesFit
EOF

# 准备 server 配置文件
# * node-ip 请替换为当前 server 节点的 IP 地址
# * token 请替换为上面生成的 token
# * cluster-cidr 和 service-cidr 设置 Pod 和 Service 的 IP 地址范围, 需要询问用户是否存在地址段冲突问题
# * tls-san 设置需要签名的 IP 或者域名，通常设置为 vip 和需要通过外网连接 k3s 的 IP 地址, 如果不设置则 kubeconfig 中需要设置跳过安全检查
# * disable 关闭 k3s 缺省部署的服务，后续步骤部署 `nginx` 和 `metallb` 作为替代
cat << 'EOF' > server.yaml
node-ip: <node-ip>
token: <token>
cluster-cidr: 172.24.0.0/13
service-cidr: 172.23.0.0/16
tls-san:
- 172.18.15.199
flannel-backend: "none"
disable-network-policy: true
disable:
- traefik
- servicelb
- local-storage
embedded-registry: true
kubelet-arg:
- runtime-request-timeout=15m
- container-log-max-files=3
- container-log-max-size=10Mi
kube-scheduler-arg:
- authentication-tolerate-lookup-failure=false
- config=/etc/rancher/k3s/scheduler.yaml
EOF

# 拷贝配置文件到所有 server 节点
pdsh -w ^server mkdir -p /etc/rancher/k3s
pdcp -w ^server scheduler.yaml /etc/rancher/k3s/scheduler.yaml
pdcp -w ^server server.yaml /etc/rancher/k3s/config.yaml
```

```sh
# 在 mn01 上初始化集群
# * 如果 k3s server 不需要支持 HA，则去掉 `--cluster-init` 即可，除 mn01 外其他所有节点使用下面 agent 方式加入集群
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
  | INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.32.4+k3s1 sh -s - server \
    --cluster-init

# 在剩余 mn[02-03] 节点上加入集群
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
  | INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.32.4+k3s1 sh -s - server \
	  --server https://172.18.15.101:6443
```

> * 对于生产环境，应当使用 `INSTALL_K3S_VERSION` 固定版本，版本信息可以从 [channel](https://update.k3s.io/v1-release/channels/stable) 中查询

### 安装 k3s agent

```sh
# 准备 agent 配置文件
# * node-ip 请替换为当前 agent 节点的 IP 地址
# * token 请替换为上面生成的 token
cat << 'EOF' > agent.yaml
node-ip: <node-ip>
token: <token>
kubelet-arg:
- runtime-request-timeout=15m
- container-log-max-files=3
- container-log-max-size=10Mi
EOF

pdsh -w ^agent mkdir -p /etc/rancher/k3s
pdcp -w ^agent agent.yaml /etc/rancher/k3s/config.yaml
```

```sh
# 在非 mn 节点上加入集群
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh \
	| INSTALL_K3S_MIRROR=cn INSTALL_K3S_VERSION=v1.32.4+k3s1 sh -s - agent \
	--server https://172.18.15.101:6443
```

### 访问 k3s 集群

- 在集群中执行 kubectl 即可访问
- 在非集群的局域网网内
  ```sh
  cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sed -i 's/127.0.0.1:6443/172.18.15.101:6443/g' ~/.kube/config
  kubectl get node
  ```
- 在外网访问，假如能通过外网 IP 1.2.3.4 访问任意的 mn 节点 7443 端口
  ```sh
  cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sed -i 's/127.0.0.1:6443/1.2.3.4:6443/g' ~/.kube/config
  kubectl get node
  ```
- 如果访问的 IP 未在 `--tls-san` 中，则需要跳过安全检查，移除 kubeconfig 中的 `certificate-authority-data: xxx` 并添加 `insecure-skip-tls-verify: true` 即可

### 常用配置

- 代理 `containerd` 拉取镜像 (必须配置，否则无法拉取镜像)

  ```sh
  # 设置 docker.io 镜像代理, 原因是 docker 官网有限速
  cat << 'EOF' > registries.yaml
  mirrors:
    docker.io:
      endpoint:
        - "https://mirror.gcr.io"
    registry.k8s.io:
    gcr.io:
    ghcr.io:
    nvcr.io:
    k8s.gcr.io:
    quay.io:
    cr.example.com:
  EOF
  pdcp -w ^all registries.yaml /etc/rancher/k3s

  # 设置 containerd 代理
  # * 假设 10.128.0.200 为代理服务器的 IP 地址，3128 为代理服务器的端口
  # * NO_PROXY 中还可以 bypass 域名，例如 `*.example.com`, 一般需要设置 harbor 搭建镜像仓库
  # 设置 `CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=3650` 使自动签订的证书有效期为10年
  cat << 'EOF' > k3s.service.env
  CONTAINERD_HTTP_PROXY=http://172.18.3.171:8080
  CONTAINERD_HTTPS_PROXY=http://172.18.3.171:8080
  CONTAINERD_NO_PROXY=127.0.0.0/8,172.18.15.0/24,172.18.15.101,172.18.15.102,172.18.15.103,172.18.15.104,*.example.com
  CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=3650
  EOF

  # 拷贝配置文件到所有 server 和 agent 节点
  cp k3s.service.env k3s-agent.service.env
  pdcp -w ^server k3s.service.env /etc/systemd/system
  pdcp -w ^agent k3s-agent.service.env /etc/systemd/system
  pdsh -w ^all systemctl daemon-reload
  pdsh -w ^server systemctl restart k3s
  pdsh -w ^agent systemctl restart k3s-agent
  ```

- 修复在训练场景无法申请大内存的问题

  ```sh
  pdsh -w ^server "sed -i '/LimitCORE/a LimitMEMLOCK=infinity' /etc/systemd/system/k3s.service"
  pdsh -w ^agent "sed -i '/LimitCORE/a LimitMEMLOCK=infinity' /etc/systemd/system/k3s-agent.service"
  pdsh -w ^all systemctl daemon-reload
  pdsh -w ^server systemctl restart k3s
  pdsh -w ^agent systemctl restart k3s-agent
  ```

- 修改 CoreDNS 和 Metrics Server 的配置

  ```bash
  kubectl patch deployment coredns -n kube-system --type merge --patch-file k3s-patch/coredns-patch.yaml

  kubectl patch deployment metrics-server -n kube-system --type merge --patch-file k3s-patch/metrics-server-patch.yaml
  ```

- 为控制节点打上污点

  ```bash
  kubectl taint node bj1mn01 node-role.kubernetes.io/control-plane:NoSchedule
  kubectl taint node bj1mn02 node-role.kubernetes.io/control-plane:NoSchedule
  kubectl taint node bj1mn03 node-role.kubernetes.io/control-plane:NoSchedule
  ```

## 卸载 k3s

```sh
pdsh -w ^agent k3s-agent-uninstall.sh
pdsh -w ^server k3s-uninstall.sh
```
