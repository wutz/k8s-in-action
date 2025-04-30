# Network Operator

当配置了 Infiniband 或者 RoCE 设备时，才需要安装 Network Operator。

## IB 部署

- 部署

  ```sh
  helmwave up --build
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
  # 所有节点执行
  ln -s /var/lib/rancher/k3s/agent/etc/cni /etc/
  mkdir /opt/cni && ln -s /var/lib/rancher/k3s/data/cni /opt/cni/bin

  helmwave up --build
  ```
- 测试

  ```sh
  ## 终端 1
  # 提交前修改 tests-roce.yaml 中每个 Pod 使用的节点名称
  kubectl apply -f tests-roce.yaml
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

  # 清理所有节点
  cd /etc/cni/net.d && mv 00-multus.conflist multus.d/ whereabouts.d/ /tmp/
  ```
