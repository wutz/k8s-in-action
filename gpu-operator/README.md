# [GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)

用于支持配置 GPU 设备的 Kubernetes 集群, 主要包含安装 GPU 驱动，Container Runtime Nvidia, K8S Device Plugin 等

- 部署

  ```sh
  helmwave up --build
  ```

  > 如果环境配置 Infiniband/RoCE 设备，设置 `values.yml` 中的 `driver.rdma` 选项

- 设置 GPU 节点缺省 Container Runtime 使用 `nvidia`

  ```sh
  pdsh -w ^all "sed -i '/token/a default-runtime: nvidia' /etc/rancher/k3s/config.yaml"
  pdsh -w ^server systemctl restart k3s
  pdsh -w ^agent systemctl restart k3s-agent
  ```

  > 只需要修改 GPU 节点的配置

- 设置 host 上 `nvidia-smi` 命令可执行

  ```sh
  cat << 'EOF' > nvidia-smi.sh
  alias nvidia-smi="chroot /run/nvidia/driver nvidia-smi"
  EOF

  pdcp -w ^all nvidia-smi.sh /etc/profile.d/
  source /etc/profile.d/nvidia-smi.sh
  ```

  > 只需要设置 GPU 节点即可

- 修改调度策略为优先填充满节点：缺省平分到节点会造成无法申请满 8 卡的节点资源

  > 修改所有 mn 节点

  ```sh
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

  pdcp -w ^server scheduler.yaml /etc/rancher/k3s/
  pdsh -w ^server "sed -i '\$a kube-scheduler-arg:\n- authentication-tolerate-lookup-failure=false\n- config=/etc/rancher/k3s/scheduler.yaml' /etc/rancher/k3s/config.yaml"
  pdsh -w ^server systemctl restart k3s
  ```

- 在 Grafana 中添加 Nvidia DCGM Dashboard (Import 时使用 ID: `21362`)

- 测试

  运行一个 Cuda 示例用于检查基础环境是否准备好

  ```sh
  k apply -f test.yml
  k logs -f cuda-vectoradd
  k delete -f test.yml
  ```

- 卸载

  ```sh
  helmwave down
  ```
