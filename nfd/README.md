# [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery)

主要根据节点硬件信息，设置 node label, 通常被其他组件服务依赖，例如 gpu-operator

- 部署

  ```sh
  helmwave up --build
  ```

  > values.yml 配置主要来自 gpu-operator

- 查看 Node Label

  ```sh
  k get node --show-labels
  ```

- 卸载

  ```sh
  helmwave down
  ```
