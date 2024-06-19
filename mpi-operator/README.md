# [MPI Operator](https://github.com/kubeflow/mpi-operator)

- 部署

  ```sh
  kubectl apply --server-side -f mpi-operator.yaml
  ```

- 运行 nccl-tests

  ```sh
  # 根据集群实际硬件配置进行修改
  kubectl apply -f nccl-tests.yml

  # 查询测试结果
  kubectl logs -f nccl-test-h100-launcher-xxx

  kubectl delete -f nccl-tests.yml
  ```

- 卸载

  ```sh
  kubectl delete --server-side -f mpi-operator.yaml
  ```
