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

- 使用自定义镜像运行 mpi-operator

  使用 mpi-operator 对于镜像只依赖 sshd 服务，下面演示如何使用上游 qwen 镜像加入 sshd 服务

  * 创建 [Dockerfile](Dockerfile): 安装和配置 ssh 相关是必须的，其它依赖是可选的
  * 构建和推送到镜像仓库

    ```bash
    export IMAGE=ghcr.io/wutz/qwen:1.5-cu121
    docker build -t $IMAGE .
    docker push $IMAGE
    ```
  * 修改 `mpi-operator.yaml` 中的镜像

- 卸载

  ```sh
  kubectl delete --server-side -f mpi-operator.yaml
  ```
