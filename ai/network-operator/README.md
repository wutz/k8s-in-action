# Network Operator

当配置了 Infiniband 或者 RoCE 设备时，才需要安装 Network Operator。

## 准备

* 下载 [OFED 驱动](https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/), 在宿主机上解压后安装 `./mlnxofedinstall -q`

## IB 部署

- 部署

  ```sh
  helmwave up --build
  kubectl apply -f ib.yaml
  ```
- 测试

  ```sh
  ## 终端 1
  # 提交前修改 tests-ib.yaml 中每个 Pod 使用的节点名称
  kubectl apply -f tests-ib.yaml
  kubectl exec -it rdma-test-pod1 -- ip a
  ib_send_bw -q 8 

  ## 终端 2
  kubectl apply -f rdma-test-pod2.yaml
  kubectl exec -it rdma-test-pod2 -- ip a
  ib_send_bw -q 8 <rdma-test-pod1 eth0 ip>
  ```

- 卸载

  ```sh
  helmwave down
  ```

## RoCE 部署

- 部署

  ```sh
  # 所有节点执行 (仅 k3s 使用内置 cni flannel 时需要)
  ln -s /var/lib/rancher/k3s/agent/etc/cni /etc/
  mkdir /opt/cni && ln -s /var/lib/rancher/k3s/data/cni /opt/cni/bin

  helmwave up --build
  kubectl apply -f roce.yaml
  ```
- 测试

  ```sh
  ## 终端 1
  # 提交前修改 tests-roce.yaml 中每个 Pod 使用的节点名称
  kubectl apply -f tests-roce.yaml
  kubectl exec -it rdma-test-pod1 -- ip a
  ib_send_bw -R -q 8 

  ## 终端 2
  kubectl apply -f rdma-test-pod2.yaml
  kubectl exec -it rdma-test-pod2 -- ip a
  ib_send_bw -R -q 8 <rdma-test-pod1 eth0 ip>
  ```

  如果 RoCE 设备运行在 Bonding 模式，则 nccl 运行需要加上额外参数 `mpirun -x NCCL_PLUGIN_P2P=ucx`

- 卸载
  ```sh
  helmwave down
  ```

- 卸载

  ```sh
  helmwave down
  ```
