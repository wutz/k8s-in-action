# [MPI Operator](https://github.com/kubeflow/mpi-operator)

## 部署

```sh
kubectl apply --server-side -k .
```

## 构建自定义镜像

使用 mpi-operator 对于镜像只依赖 sshd 服务，下面演示如何使用上游 ubuntu:22.04 镜像加入 sshd 服务

* 创建 [Dockerfile](Dockerfile): 安装和配置 ssh 相关是必须的，其它依赖是可选的
* 构建和推送到镜像仓库

  ```bash
  export IMAGE=ghcr.io/wutz/ubuntu:22.04
  docker build -t $IMAGE .
  docker push $IMAGE
  ```
* 修改 `mpi-operator.yaml` 中的镜像

## 卸载

```sh
kubectl delete --server-side -k .
```
